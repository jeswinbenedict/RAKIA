// SPDX-License-Identifier: Apache-2.0
//
// Sync of an astronaut's own record from a device: a batch of hash-chained
// measurements. Before anything is stored, every record's hash is recomputed
// with librakia (the same code that produced it on the device) and the chain
// inside the batch is checked; the database then checks that the batch
// continues the chain it already holds. Simulated data is never accepted.
#pragma once

#include <cstdint>
#include <nlohmann/json_fwd.hpp>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

namespace rakia {

struct SyncRecord {
  std::string id;  // UUID
  std::string metric_code;
  double value = 0;
  std::string unit;  // UCUM code, as hashed on the device
  std::int64_t observed_at_us = 0;
  int method = 0;      // rakia_method
  int provenance = 0;  // rakia_provenance
  int quality_flags = 0;
  std::int64_t client_seq = 0;
  std::string prev_hash;  // 64 hex characters
  std::string hash;       // 64 hex characters
  std::optional<std::string> supersedes_id;
};

struct SyncBatch {
  std::string batch_id;
  std::string client_id;
  std::string mission_id;
  std::string mission_name;
  std::int64_t mission_start_us = 0;
  int planned_days = 0;
  std::string subject_id;
  std::vector<SyncRecord> records;
};

struct SyncResult {
  std::int64_t acked_through_seq = 0;
  /// Records stored by this request (0 when everything was already held).
  int accepted = 0;
  /// The batch id had been processed before; nothing was done again.
  bool duplicate = false;
};

/// A batch that cannot be accepted. [code] is sent to the client with
/// [status]; the message is for the user and never contains health data.
class SyncError : public std::runtime_error {
 public:
  SyncError(int http_status, std::string error_code, const std::string& message)
      : std::runtime_error(message), status(http_status), code(std::move(error_code)) {}
  int status;
  std::string code;
};

/// Most records one batch may carry.
inline constexpr std::size_t kMaxSyncRecords = 500;

/// Parses and validates the request body (shape, UUIDs, ranges, sizes).
/// Throws SyncError (400).
SyncBatch parse_sync_batch(const nlohmann::json& body);

/// Recomputes every record's hash with librakia and checks that the batch
/// is one continuous chain. Throws SyncError (400 `hash_mismatch` or
/// `chain_broken`).
void verify_batch(const SyncBatch& batch);

/// The 16 bytes of a canonical lower-case UUID string; nullopt when it is
/// not one.
std::optional<std::string> uuid_bytes(const std::string& text);

}  // namespace rakia
