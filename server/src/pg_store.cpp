// SPDX-License-Identifier: Apache-2.0
#include "pg_store.hpp"

#include <libpq-fe.h>

#include <cstdio>
#include <map>
#include <memory>
#include <nlohmann/json.hpp>
#include <string>

#include "log.hpp"
#include "security.hpp"

namespace rakia {
namespace {

struct ResultDeleter {
  void operator()(PGresult* r) const { PQclear(r); }
};
using Result = std::unique_ptr<PGresult, ResultDeleter>;

[[noreturn]] void throw_result(PGresult* r, pg_conn* conn) {
  const char* state = r ? PQresultErrorField(r, PG_DIAG_SQLSTATE) : nullptr;
  const std::string message = r ? PQresultErrorMessage(r) : PQerrorMessage(conn);
  if (PQstatus(conn) != CONNECTION_OK) throw StoreUnavailable("database connection lost");
  throw QueryError(state ? state : "XX000", message);
}

Result exec(pg_conn* conn, const std::string& sql,
            const std::vector<std::optional<std::string>>& params) {
  std::vector<const char*> values;
  values.reserve(params.size());
  for (const auto& p : params) values.push_back(p ? p->c_str() : nullptr);
  Result r(PQexecParams(conn, sql.c_str(), static_cast<int>(values.size()), nullptr,
                        values.empty() ? nullptr : values.data(), nullptr, nullptr, 0));
  const auto status = r ? PQresultStatus(r.get()) : PGRES_FATAL_ERROR;
  if (status != PGRES_COMMAND_OK && status != PGRES_TUPLES_OK) throw_result(r.get(), conn);
  return r;
}

}  // namespace

Rows Tx::query(const std::string& sql, const std::vector<std::optional<std::string>>& params) {
  const auto r = exec(conn_, sql, params);
  Rows rows;
  const int n = PQntuples(r.get());
  const int cols = PQnfields(r.get());
  rows.reserve(static_cast<std::size_t>(n));
  for (int i = 0; i < n; ++i) {
    Row row;
    row.reserve(static_cast<std::size_t>(cols));
    for (int c = 0; c < cols; ++c) {
      if (PQgetisnull(r.get(), i, c)) {
        row.emplace_back(std::nullopt);
      } else {
        row.emplace_back(std::string(PQgetvalue(r.get(), i, c),
                                     static_cast<std::size_t>(PQgetlength(r.get(), i, c))));
      }
    }
    rows.push_back(std::move(row));
  }
  return rows;
}

PgStore::PgStore(const Config& c, std::chrono::milliseconds acquire_timeout)
    : acquire_timeout_(acquire_timeout), capacity_(c.db_pool_size) {
  // Keyword/value pairs, so no value is ever parsed as part of a string.
  keywords_ = {"host",    "port",          "dbname",           "user",   "password",
               "sslmode", "application_name", "connect_timeout", "options"};
  values_ = {c.db_host,    std::to_string(c.db_port), c.db_name, c.db_user, c.db_password,
             c.db_sslmode, "rakia-api",                "5",
             // A runaway statement or a forgotten transaction cannot hold
             // a connection for long.
             "-c statement_timeout=10000 -c idle_in_transaction_session_timeout=15000"};
  if (!c.db_sslrootcert.empty()) {
    // "system" (libpq 16+) verifies against the operating system's roots.
    keywords_.emplace_back("sslrootcert");
    values_.push_back(c.db_sslrootcert);
  }
}

PgStore::~PgStore() {
  const std::lock_guard<std::mutex> lock(mutex_);
  for (auto* conn : idle_) PQfinish(conn);
  idle_.clear();
}

pg_conn* PgStore::connect() {
  std::vector<const char*> k;
  std::vector<const char*> v;
  for (std::size_t i = 0; i < keywords_.size(); ++i) {
    k.push_back(keywords_[i].c_str());
    v.push_back(values_[i].c_str());
  }
  k.push_back(nullptr);
  v.push_back(nullptr);
  pg_conn* conn = PQconnectdbParams(k.data(), v.data(), 0);
  if (PQstatus(conn) != CONNECTION_OK) {
    // libpq's message can name the host and user but never the password.
    log::warn("database connection failed", {{"detail", PQerrorMessage(conn)}});
    PQfinish(conn);
    throw StoreUnavailable("database unavailable");
  }
  return conn;
}

pg_conn* PgStore::acquire() {
  std::unique_lock<std::mutex> lock(mutex_);
  if (!available_.wait_for(lock, acquire_timeout_,
                           [&] { return !idle_.empty() || leased_ < capacity_; })) {
    throw StoreUnavailable("no database connection available");
  }
  if (!idle_.empty()) {
    auto* conn = idle_.back();
    idle_.pop_back();
    ++leased_;
    lock.unlock();
    if (PQstatus(conn) == CONNECTION_OK) return conn;
    PQfinish(conn);
    lock.lock();
    --leased_;
    lock.unlock();
    available_.notify_one();
    return acquire();
  }
  ++leased_;
  lock.unlock();
  try {
    return connect();
  } catch (...) {
    {
      const std::lock_guard<std::mutex> relock(mutex_);
      --leased_;
    }
    available_.notify_one();
    throw;
  }
}

void PgStore::release(pg_conn* conn) {
  {
    const std::lock_guard<std::mutex> lock(mutex_);
    --leased_;
    if (conn != nullptr && PQstatus(conn) == CONNECTION_OK &&
        PQtransactionStatus(conn) == PQTRANS_IDLE) {
      idle_.push_back(conn);
      conn = nullptr;
    }
  }
  if (conn != nullptr) PQfinish(conn);
  available_.notify_one();
}

void PgStore::transaction(const std::optional<std::string>& caller_uid,
                          const std::function<void(Tx&)>& body) {
  pg_conn* conn = acquire();
  try {
    exec(conn, "BEGIN", {});
    if (caller_uid) {
      // Built with a JSON library, so the uid is always a properly escaped
      // string; set_config(..., true) scopes it to this transaction.
      const auto claims = nlohmann::json{{"sub", *caller_uid}}.dump();
      exec(conn, "SELECT set_config('request.jwt.claims', $1, true)", {claims});
    }
    Tx tx(conn);
    body(tx);
    exec(conn, "COMMIT", {});
  } catch (...) {
    if (PQstatus(conn) == CONNECTION_OK && PQtransactionStatus(conn) != PQTRANS_IDLE) {
      Result r(PQexec(conn, "ROLLBACK"));
    }
    release(conn);
    throw;
  }
  release(conn);
}

int PgStore::schema_version() {
  int version = 0;
  transaction(std::nullopt, [&](Tx& tx) {
    const auto rows = tx.query("SELECT rakia.schema_version()");
    version = std::stoi(rows.at(0).at(0).value());
  });
  return version;
}

std::vector<MetricDefinition> PgStore::metric_definitions() {
  std::vector<MetricDefinition> out;
  transaction(std::nullopt, [&](Tx& tx) {
    for (const auto& r : tx.query(
             "SELECT code, name, unit, ucum, plausible_min, plausible_max "
             "FROM rakia.metric_definitions ORDER BY code")) {
      out.push_back({r.at(0).value(), r.at(1).value(), r.at(2).value(), r.at(3).value(),
                     std::stod(r.at(4).value()), std::stod(r.at(5).value())});
    }
  });
  return out;
}

std::optional<Account> read_account(Tx& tx) {
  const auto rows = tx.query(
      "SELECT id::text, firebase_uid, display_name, "
      "to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') "
      "FROM rakia.app_users WHERE firebase_uid = rakia.current_uid()");
  if (rows.empty()) return std::nullopt;
  Account a;
  a.id = rows[0].at(0).value();
  a.firebase_uid = rows[0].at(1).value();
  a.display_name = rows[0].at(2);
  a.created_at = rows[0].at(3).value();
  for (const auto& r : tx.query(
           "SELECT m.id::text, m.name, m.is_simulation, mm.role::text "
           "FROM rakia.mission_members mm JOIN rakia.missions m ON m.id = mm.mission_id "
           "WHERE mm.user_id = rakia.current_user_id() ORDER BY m.name, mm.role")) {
    a.memberships.push_back(
        {r.at(0).value(), r.at(1).value(), r.at(2).value() == "t", r.at(3).value()});
  }
  return a;
}

Account load_account(Tx& tx, const std::string& firebase_uid, const std::string& new_id) {
  // Row-level security lets a user create and read only their own record.
  tx.query(
      "INSERT INTO rakia.app_users (id, firebase_uid) VALUES ($1::uuid, $2) "
      "ON CONFLICT (firebase_uid) DO NOTHING",
      {new_id, firebase_uid});
  auto a = read_account(tx);
  if (!a) throw QueryError("42501", "account not visible to its own user");
  return *a;
}

std::optional<Account> PgStore::find_account(const std::string& firebase_uid) {
  std::optional<Account> a;
  transaction(firebase_uid, [&](Tx& tx) { a = read_account(tx); });
  return a;
}

Account PgStore::create_account(const std::string& firebase_uid) {
  Account a;
  transaction(firebase_uid,
              [&](Tx& tx) { a = load_account(tx, firebase_uid, new_uuid_v7()); });
  return a;
}

bool PgStore::remember_turnstile_token(const std::string& hash_hex) {
  bool fresh = false;
  transaction(std::nullopt, [&](Tx& tx) {
    tx.query("DELETE FROM rakia.turnstile_replay WHERE expires_at < now()");
    fresh = !tx.query(
                   "INSERT INTO rakia.turnstile_replay (token_hash, expires_at) "
                   "VALUES (decode($1, 'hex'), now() + interval '10 minutes') "
                   "ON CONFLICT (token_hash) DO NOTHING RETURNING 1",
                   {hash_hex})
                .empty();
  });
  return fresh;
}

namespace {

/// A double as text that PostgreSQL parses back to the same value.
std::string exact(double v) {
  char buf[40];
  std::snprintf(buf, sizeof buf, "%.17g", v);
  return buf;
}

constexpr const char* kMethods[] = {"measured", "manual", "estimated", "derived"};
constexpr const char* kProvenance[] = {"real", "imported"};
const std::string kZeroHash(64, '0');

}  // namespace

SyncResult apply_sync_batch(Tx& tx, const SyncBatch& b) {
  if (!read_account(tx)) {
    throw SyncError(409, "no_account", "Create your RAKIA account before syncing.");
  }
  if (const auto done = tx.query(
          "SELECT acked_through_seq::text FROM rakia.sync_batches WHERE id = $1::uuid",
          {b.batch_id});
      !done.empty()) {
    return {std::stoll(done[0].at(0).value()), 0, true};
  }

  const auto mission =
      tx.query("SELECT is_simulation FROM rakia.missions WHERE id = $1::uuid", {b.mission_id});
  if (mission.empty()) {
    const auto owned = tx.query(
        "SELECT count(*)::text FROM rakia.missions "
        "WHERE created_by = rakia.current_user_id() AND NOT is_simulation");
    if (std::stoi(owned[0].at(0).value()) >= kMaxRecordsPerAccount) {
      throw SyncError(409, "too_many_records",
                      "This account already has the most health records it may hold.");
    }
    tx.query(
        "INSERT INTO rakia.missions (id, name, is_simulation, starts_at, planned_days, created_by) "
        "VALUES ($1::uuid, $2, false, "
        "'epoch'::timestamptz + $3::bigint * interval '1 microsecond', $4::int, "
        "rakia.current_user_id())",
        {b.mission_id, b.mission_name, std::to_string(b.mission_start_us),
         std::to_string(b.planned_days)});
    // The creator claims the record, then is its astronaut: the only person
    // (with medical staff they may add later) who can read its health data.
    for (const char* role : {"mission_admin", "astronaut"}) {
      tx.query(
          "INSERT INTO rakia.mission_members (mission_id, user_id, role) "
          "VALUES ($1::uuid, rakia.current_user_id(), $2::rakia.member_role)",
          {b.mission_id, std::string(role)});
    }
    tx.query(
        "INSERT INTO rakia.crew_members (id, mission_id, user_id, label) "
        "VALUES ($1::uuid, $2::uuid, rakia.current_user_id(), 'Me')",
        {b.subject_id, b.mission_id});
  } else {
    if (mission[0].at(0).value() == "t") {
      throw SyncError(400, "simulated_data", "Simulation missions are never synced.");
    }
    if (tx.query("SELECT 1 FROM rakia.crew_members WHERE id = $1::uuid AND mission_id = $2::uuid "
                 "AND user_id = rakia.current_user_id()",
                 {b.subject_id, b.mission_id})
            .empty()) {
      throw SyncError(403, "not_your_record", "This health record belongs to another account.");
    }
  }

  if (tx.query("SELECT 1 FROM rakia.clients WHERE id = $1::uuid", {b.client_id}).empty()) {
    tx.query("INSERT INTO rakia.clients (id, user_id) VALUES ($1::uuid, rakia.current_user_id())",
             {b.client_id});
  }

  std::map<std::string, std::string> ucum;
  for (const auto& r : tx.query("SELECT code, ucum FROM rakia.metric_definitions")) {
    ucum[r.at(0).value()] = r.at(1).value();
  }

  std::int64_t last_seq = 0;
  std::string last_hash = kZeroHash;
  if (const auto last = tx.query(
          "SELECT client_seq::text, encode(hash, 'hex') FROM rakia.measurements "
          "WHERE client_id = $1::uuid AND mission_id = $2::uuid "
          "ORDER BY client_seq DESC LIMIT 1",
          {b.client_id, b.mission_id});
      !last.empty()) {
    last_seq = std::stoll(last[0].at(0).value());
    last_hash = last[0].at(1).value();
  }

  SyncResult result;
  for (const auto& r : b.records) {
    const auto unit = ucum.find(r.metric_code);
    if (unit == ucum.end()) {
      throw SyncError(400, "unknown_metric", "The server does not know one of the indicators.");
    }
    if (r.unit != unit->second) {
      throw SyncError(400, "wrong_unit", "A record is not in its indicator's unit.");
    }
    if (r.client_seq <= last_seq) {
      // Already held (a batch resent after a lost answer): it must be the
      // same record.
      const auto held = tx.query(
          "SELECT encode(hash, 'hex') FROM rakia.measurements "
          "WHERE client_id = $1::uuid AND mission_id = $2::uuid AND client_seq = $3::bigint",
          {b.client_id, b.mission_id, std::to_string(r.client_seq)});
      if (held.empty() || held[0].at(0).value() != r.hash) {
        throw SyncError(409, "chain_conflict",
                        "The server holds different records for this device. Nothing was "
                        "changed.");
      }
      continue;
    }
    if (r.client_seq != last_seq + 1 || r.prev_hash != last_hash) {
      throw SyncError(409, "chain_gap",
                      "The batch does not continue the records the server holds (it expects "
                      "sequence " + std::to_string(last_seq + 1) + ").");
    }
    tx.query(
        "INSERT INTO rakia.measurements (id, mission_id, crew_member_id, metric_code, value, "
        "unit, observed_at, method, provenance, quality_flags, client_id, client_seq, "
        "prev_hash, hash, supersedes_id) VALUES ($1::uuid, $2::uuid, $3::uuid, $4, $5::float8, "
        "(SELECT unit FROM rakia.metric_definitions WHERE code = $4), "
        "'epoch'::timestamptz + $6::bigint * interval '1 microsecond', "
        "$7::rakia.measurement_method, $8::rakia.provenance, $9::int, $10::uuid, $11::bigint, "
        "decode($12, 'hex'), decode($13, 'hex'), $14::uuid)",
        {r.id, b.mission_id, b.subject_id, r.metric_code, exact(r.value),
         std::to_string(r.observed_at_us), std::string(kMethods[r.method - 1]),
         std::string(kProvenance[r.provenance - 1]), std::to_string(r.quality_flags),
         b.client_id, std::to_string(r.client_seq), r.prev_hash, r.hash, r.supersedes_id});
    last_seq = r.client_seq;
    last_hash = r.hash;
    ++result.accepted;
  }

  tx.query(
      "INSERT INTO rakia.sync_batches (id, client_id, mission_id, record_count, "
      "acked_through_seq) VALUES ($1::uuid, $2::uuid, $3::uuid, $4::int, $5::bigint)",
      {b.batch_id, b.client_id, b.mission_id, std::to_string(b.records.size()),
       std::to_string(last_seq)});
  result.acked_through_seq = last_seq;
  return result;
}

SyncResult PgStore::sync_batch(const std::string& firebase_uid, const SyncBatch& batch) {
  SyncResult result;
  try {
    transaction(firebase_uid, [&](Tx& tx) { result = apply_sync_batch(tx, batch); });
  } catch (const QueryError& e) {
    // Integrity rules (23xxx: keys, checks, the ledger triggers) and
    // row-level security (42501) refuse records that do not belong here.
    if (e.sqlstate.rfind("23", 0) == 0 || e.sqlstate == "42501") {
      log::info("sync refused by the database", {{"sqlstate", e.sqlstate}});
      throw SyncError(409, "sync_conflict",
                      "The server could not accept these records: they conflict with what it "
                      "holds. Nothing was changed.");
    }
    throw;
  }
  return result;
}

}  // namespace rakia
