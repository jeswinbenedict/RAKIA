// SPDX-License-Identifier: Apache-2.0
// PostgreSQL integration, as rakia_api against a migrated database (the
// settings in .env or RAKIA_ENV_FILE). Read-only: safe against any
// development database. Skipped unless RAKIA_API_PG_TESTS=1.
#include <cstdlib>
#include <string>

#include "config.hpp"
#include "log.hpp"
#include "pg_store.hpp"
#include "rk_test.hpp"
#include "security.hpp"
#include "sync_fixture.hpp"

namespace {

std::string env(const char* name) {
#if defined(_MSC_VER)
  char* value = nullptr;
  std::size_t len = 0;
  std::string out;
  if (_dupenv_s(&value, &len, name) == 0 && value != nullptr) {
    out = value;
    std::free(value);
  }
  return out;
#else
  const char* v = std::getenv(name);
  return v ? v : "";
#endif
}

rakia::Config pg_config() {
  const auto path = env("RAKIA_ENV_FILE").empty() ? std::string("../.env") : env("RAKIA_ENV_FILE");
  return rakia::load_config(rakia::read_env_file(path), rakia::process_environment());
}

rakia::PgStore& store() {
  static rakia::PgStore s(pg_config());
  return s;
}

}  // namespace

TEST("the schema is the version this build expects") {
  CHECK_EQ(store().schema_version(), rakia::kExpectedSchemaVersion);
}

TEST("reference data is readable") {
  const auto defs = store().metric_definitions();
  CHECK_EQ(defs.size(), std::size_t{5});
  CHECK_EQ(defs.front().code, std::string("exercise.duration"));
}

TEST("the caller's uid is set for one transaction only") {
  std::optional<std::string> seen;
  store().transaction(std::string("uid-with-\"quotes\"-and-\\"), [&](rakia::Tx& tx) {
    seen = tx.query("SELECT rakia.current_uid()").at(0).at(0);
  });
  CHECK(seen.has_value());
  CHECK_EQ(*seen, std::string("uid-with-\"quotes\"-and-\\"));
  store().transaction(std::nullopt, [&](rakia::Tx& tx) {
    seen = tx.query("SELECT rakia.current_uid()").at(0).at(0);
  });
  CHECK(!seen.has_value());
}

TEST("without a caller, row-level security shows nothing") {
  store().transaction(std::nullopt, [&](rakia::Tx& tx) {
    CHECK_EQ(tx.query("SELECT count(*) FROM rakia.missions").at(0).at(0).value(),
             std::string("0"));
  });
}

TEST("parameters are bound, never spliced") {
  store().transaction(std::nullopt, [&](rakia::Tx& tx) {
    const auto r = tx.query("SELECT $1::text", {std::string("'); DROP TABLE x; --")});
    CHECK_EQ(r.at(0).at(0).value(), std::string("'); DROP TABLE x; --"));
  });
}

TEST("an exception rolls the transaction back and the connection is reused") {
  CHECK_THROWS(std::runtime_error, store().transaction(std::nullopt, [](rakia::Tx& tx) {
    tx.query("SELECT 1");
    throw std::runtime_error("abort");
  }));
  CHECK_EQ(store().schema_version(), rakia::kExpectedSchemaVersion);
}

TEST("database errors carry the SQLSTATE") {
  try {
    store().transaction(std::nullopt, [](rakia::Tx& tx) { tx.query("SELECT * FROM rakia.no_such"); });
    CHECK(false);
  } catch (const rakia::QueryError& e) {
    CHECK_EQ(e.sqlstate, std::string("42P01"));
  }
}

TEST("the API role cannot write reference data") {
  try {
    store().transaction(std::nullopt, [](rakia::Tx& tx) {
      tx.query("UPDATE rakia.metric_definitions SET unit = 'x'");
    });
    CHECK(false);
  } catch (const rakia::QueryError& e) {
    CHECK_EQ(e.sqlstate, std::string("42501"));
  }
}

TEST("an account is created once, as its own user, and only in that transaction") {
  struct Rollback {};
  const auto uid = "rakia-pg-test-" + rakia::new_uuid_v7();
  try {
    store().transaction(uid, [&](rakia::Tx& tx) {
      const auto a = rakia::load_account(tx, uid, rakia::new_uuid_v7());
      CHECK_EQ(a.firebase_uid, uid);
      CHECK(!a.display_name.has_value());
      CHECK(a.memberships.empty());
      CHECK_EQ(a.created_at.size(), std::size_t{20});
      // A second call finds the same record instead of creating another.
      const auto again = rakia::load_account(tx, uid, rakia::new_uuid_v7());
      CHECK_EQ(again.id, a.id);
      throw Rollback{};  // leave no test user behind
    });
  } catch (const Rollback&) {
  }
  store().transaction(uid, [&](rakia::Tx& tx) {
    CHECK_EQ(tx.query("SELECT count(*) FROM rakia.app_users").at(0).at(0).value(),
             std::string("0"));
  });
}

TEST("finding an account never creates one; creating it is idempotent") {
  struct Rollback {};
  const auto uid = "rakia-pg-test-" + rakia::new_uuid_v7();
  try {
    store().transaction(uid, [&](rakia::Tx& tx) {
      CHECK(!rakia::read_account(tx).has_value());
      CHECK_EQ(tx.query("SELECT count(*) FROM rakia.app_users").at(0).at(0).value(),
               std::string("0"));
      const auto a = rakia::load_account(tx, uid, rakia::new_uuid_v7());
      const auto found = rakia::read_account(tx);
      CHECK(found.has_value());
      CHECK_EQ(found->id, a.id);
      throw Rollback{};
    });
  } catch (const Rollback&) {
  }
}

TEST("a Turnstile token hash is accepted once, then refused as a replay") {
  const auto hash = std::string(64, 'a').replace(0, 12, rakia::new_uuid_v7().substr(0, 8) + "abcd");
  CHECK(store().remember_turnstile_token(hash));
  CHECK(!store().remember_turnstile_token(hash));
  // Leave nothing behind: the test role may delete its own rows.
  store().transaction(std::nullopt, [&](rakia::Tx& tx) {
    tx.query("DELETE FROM rakia.turnstile_replay WHERE token_hash = decode($1, 'hex')", {hash});
  });
}

TEST("sync: a first batch creates the record, later batches extend it, resends are harmless") {
  struct Rollback {};
  using nlohmann::json;
  const auto uid = "rakia-pg-sync-" + rakia::new_uuid_v7();
  const auto parse = [](const json& j) {
    auto b = rakia::parse_sync_batch(j);
    rakia::verify_batch(b);
    return b;
  };
  const auto refused = [](rakia::Tx& tx, const rakia::SyncBatch& b) {
    try {
      rakia::apply_sync_batch(tx, b);
    } catch (const rakia::SyncError& e) {
      return e.code;
    }
    return std::string("accepted");
  };
  try {
    store().transaction(uid, [&](rakia::Tx& tx) {
      rk::Device d;
      const auto first = parse(d.batch(json::array({d.record("heart_rate.resting", 58.0, "/min"),
                                                    d.record("sleep.duration", 7.25, "h")})));
      // No RAKIA account yet: nothing is stored.
      CHECK_EQ(refused(tx, first), std::string("no_account"));
      rakia::load_account(tx, uid, rakia::new_uuid_v7());

      auto r = rakia::apply_sync_batch(tx, first);
      CHECK_EQ(r.acked_through_seq, std::int64_t{2});
      CHECK_EQ(r.accepted, 2);
      CHECK(!r.duplicate);

      // The record is the caller's: a real mission with them as astronaut.
      const auto a = rakia::read_account(tx);
      CHECK_EQ(a->memberships.size(), std::size_t{2});
      CHECK(!a->memberships[0].is_simulation);
      // Stored exactly: value, display unit, microsecond time, provenance.
      const auto rows = tx.query(
          "SELECT value::text, unit, provenance::text, method::text, "
          "(extract(epoch FROM observed_at) * 1000000)::bigint::text, encode(hash, 'hex') "
          "FROM rakia.measurements WHERE mission_id = $1::uuid ORDER BY client_seq",
          {d.mission_id});
      CHECK_EQ(rows.size(), std::size_t{2});
      CHECK_EQ(rows[1].at(0).value(), std::string("7.25"));
      CHECK_EQ(rows[0].at(1).value(), std::string("bpm"));
      CHECK_EQ(rows[0].at(2).value(), std::string("real"));
      CHECK_EQ(rows[0].at(3).value(), std::string("manual"));
      CHECK_EQ(rows[0].at(4).value(), std::string("1794225600000000"));
      CHECK_EQ(rows[1].at(5).value(), first.records[1].hash);

      // The same batch again: recognised by its id.
      r = rakia::apply_sync_batch(tx, first);
      CHECK(r.duplicate);
      CHECK_EQ(r.acked_through_seq, std::int64_t{2});

      // A new batch that overlaps what is held and adds one record.
      auto third = d.record("heart_rate.resting", 60.0, "/min");
      auto resend = d.batch(json::array());
      {
        // Rebuild the first two records as JSON from the parsed batch.
        json recs = json::array();
        for (const auto& rec : first.records) {
          recs.push_back({{"id", rec.id},
                          {"metric_code", rec.metric_code},
                          {"value", rec.value},
                          {"unit", rec.unit},
                          {"observed_at_us", rec.observed_at_us},
                          {"method", rec.method},
                          {"provenance", rec.provenance},
                          {"quality_flags", rec.quality_flags},
                          {"client_seq", rec.client_seq},
                          {"prev_hash", rec.prev_hash},
                          {"hash", rec.hash}});
        }
        recs.push_back(third);
        resend["records"] = recs;
      }
      r = rakia::apply_sync_batch(tx, parse(resend));
      CHECK_EQ(r.accepted, 1);
      CHECK_EQ(r.acked_through_seq, std::int64_t{3});

      // A gap (record 5 without 4) is refused.
      d.record("heart_rate.resting", 61.0, "/min");  // 4, never sent
      const auto fifth = parse(d.batch(json::array({d.record("heart_rate.resting", 62.0, "/min")})));
      CHECK_EQ(refused(tx, fifth), std::string("chain_gap"));

      // A different history for the same device and sequence is refused.
      rk::Device fork = d;
      fork.seq = 0;
      fork.last_hash = std::string(64, '0');
      const auto other = parse(fork.batch(json::array({fork.record("heart_rate.resting", 99.0, "/min")})));
      CHECK_EQ(refused(tx, other), std::string("chain_conflict"));

      // Units and indicators the server does not know.
      rk::Device e;
      e.mission_id = d.mission_id;
      e.subject_id = d.subject_id;
      CHECK_EQ(refused(tx, parse(e.batch(json::array({e.record("heart_rate.resting", 58.0, "bpm")})))),
               std::string("wrong_unit"));
      rk::Device f;
      f.mission_id = d.mission_id;
      f.subject_id = d.subject_id;
      CHECK_EQ(refused(tx, parse(f.batch(json::array({f.record("blood.pressure", 120.0, "mm[Hg]")})))),
               std::string("unknown_metric"));

      // Someone else's subject in this record.
      rk::Device g;
      g.mission_id = d.mission_id;
      CHECK_EQ(refused(tx, parse(g.batch(json::array({g.record("heart_rate.resting", 58.0, "/min")})))),
               std::string("not_your_record"));
      throw Rollback{};  // real records cannot be deleted; leave nothing behind
    });
  } catch (const Rollback&) {
  }
  store().transaction(uid, [&](rakia::Tx& tx) {
    CHECK_EQ(tx.query("SELECT count(*) FROM rakia.missions").at(0).at(0).value(),
             std::string("0"));
  });
}

TEST("a user cannot create an account for someone else") {
  try {
    store().transaction(std::string("caller-a"), [](rakia::Tx& tx) {
      tx.query("INSERT INTO rakia.app_users (id, firebase_uid) VALUES ($1::uuid, 'caller-b')",
               {rakia::new_uuid_v7()});
    });
    CHECK(false);
  } catch (const rakia::QueryError& e) {
    CHECK_EQ(e.sqlstate, std::string("42501"));
  }
}

TEST("an unreachable database is reported as unavailable") {
  auto c = pg_config();
  c.db_port = 1;  // nothing listens there
  rakia::PgStore down(c, std::chrono::milliseconds(500));
  CHECK_THROWS(rakia::StoreUnavailable, down.schema_version());
}

int main() {
  if (env("RAKIA_API_PG_TESTS") != "1") {
    std::printf("pg: skipped (set RAKIA_API_PG_TESTS=1 with a migrated database)\n");
    return 0;
  }
  rakia::log::set_enabled(false);
  return rk::run("pg");
}
