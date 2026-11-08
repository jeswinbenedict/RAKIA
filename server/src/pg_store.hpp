// SPDX-License-Identifier: Apache-2.0
#pragma once

#include <chrono>
#include <condition_variable>
#include <cstddef>
#include <functional>
#include <mutex>
#include <optional>
#include <string>
#include <vector>

#include "config.hpp"
#include "store.hpp"

struct pg_conn;

namespace rakia {

using Row = std::vector<std::optional<std::string>>;
using Rows = std::vector<Row>;

/// One transaction on a pooled connection. Statements take parameters
/// only as bound values ($1, $2, ...), never spliced into SQL.
class Tx {
 public:
  Rows query(const std::string& sql, const std::vector<std::optional<std::string>>& params = {});

 private:
  friend class PgStore;
  explicit Tx(pg_conn* conn) : conn_(conn) {}
  pg_conn* conn_;
};

/// PostgreSQL through libpq, as the least-privilege rakia_api role. A fixed
/// pool of connections, opened lazily and reopened after a failure, so the
/// API starts (and reports not ready) while the database is down.
/// The account of the caller of [tx] (a transaction run with their uid),
/// creating the record with [new_id] if it does not exist yet.
Account load_account(Tx& tx, const std::string& firebase_uid, const std::string& new_id);

class PgStore final : public Store {
 public:
  explicit PgStore(const Config& config,
                   std::chrono::milliseconds acquire_timeout = std::chrono::seconds(2));
  ~PgStore() override;
  PgStore(const PgStore&) = delete;
  PgStore& operator=(const PgStore&) = delete;

  /// Runs [body] in one transaction. With [caller_uid], the verified
  /// Firebase uid is placed in request.jwt.claims for this transaction
  /// only, so row-level security applies to that user; without it the
  /// transaction sees only what is visible to no one in particular.
  /// Commits when [body] returns, rolls back when it throws.
  void transaction(const std::optional<std::string>& caller_uid,
                   const std::function<void(Tx&)>& body);

  int schema_version() override;
  std::vector<MetricDefinition> metric_definitions() override;
  Account account(const std::string& firebase_uid) override;

 private:
  pg_conn* acquire();
  void release(pg_conn* conn);
  pg_conn* connect();

  std::vector<std::string> keywords_;
  std::vector<std::string> values_;
  std::chrono::milliseconds acquire_timeout_;

  std::mutex mutex_;
  std::condition_variable available_;
  std::size_t capacity_;
  std::size_t leased_ = 0;
  std::vector<pg_conn*> idle_;
};

}  // namespace rakia
