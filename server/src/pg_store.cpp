// SPDX-License-Identifier: Apache-2.0
#include "pg_store.hpp"

#include <libpq-fe.h>

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

Account load_account(Tx& tx, const std::string& firebase_uid, const std::string& new_id) {
  // Row-level security lets a user create and read only their own record.
  tx.query(
      "INSERT INTO rakia.app_users (id, firebase_uid) VALUES ($1::uuid, $2) "
      "ON CONFLICT (firebase_uid) DO NOTHING",
      {new_id, firebase_uid});
  const auto rows = tx.query(
      "SELECT id::text, firebase_uid, display_name, "
      "to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') "
      "FROM rakia.app_users WHERE firebase_uid = rakia.current_uid()");
  if (rows.size() != 1) throw QueryError("42501", "account not visible to its own user");
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

Account PgStore::account(const std::string& firebase_uid) {
  Account a;
  transaction(firebase_uid,
              [&](Tx& tx) { a = load_account(tx, firebase_uid, new_uuid_v7()); });
  return a;
}

}  // namespace rakia
