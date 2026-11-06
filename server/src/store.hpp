// SPDX-License-Identifier: Apache-2.0
#pragma once

#include <stdexcept>
#include <string>
#include <vector>

namespace rakia {

/// The database schema this build of the API expects (db/migrations).
inline constexpr int kExpectedSchemaVersion = 2;

struct MetricDefinition {
  std::string code;
  std::string name;
  std::string unit;
  std::string ucum;
  double plausible_min = 0;
  double plausible_max = 0;
};

/// The database cannot be reached or no connection was free in time.
class StoreUnavailable : public std::runtime_error {
 public:
  using std::runtime_error::runtime_error;
};

/// A statement failed. [sqlstate] is safe to log; the server's message is
/// kept for logs only and never sent to clients.
class QueryError : public std::runtime_error {
 public:
  QueryError(std::string state, const std::string& message)
      : std::runtime_error(message), sqlstate(std::move(state)) {}
  std::string sqlstate;
};

/// What the HTTP layer needs from the database. PgStore implements it;
/// tests substitute a fake.
class Store {
 public:
  virtual ~Store() = default;
  /// rakia.schema_version(): the latest applied migration.
  virtual int schema_version() = 0;
  /// Reference data: the indicators RAKIA understands.
  virtual std::vector<MetricDefinition> metric_definitions() = 0;
};

}  // namespace rakia
