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
