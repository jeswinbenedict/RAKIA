// SPDX-License-Identifier: Apache-2.0
#pragma once

#include <optional>
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

/// A mission the signed-in user belongs to, with one of their roles in it.
struct Membership {
  std::string mission_id;
  std::string mission_name;
  bool is_simulation = false;
  std::string role;
};

/// The signed-in user's account record and memberships.
struct Account {
  std::string id;
  std::string firebase_uid;
  std::optional<std::string> display_name;
  std::string created_at;
  std::vector<Membership> memberships;
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
  /// The account of the verified Firebase user [firebase_uid], created on
  /// first use, as that user (row-level security applies).
  virtual Account account(const std::string& firebase_uid) = 0;
};

}  // namespace rakia
