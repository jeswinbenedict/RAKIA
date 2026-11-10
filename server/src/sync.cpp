// SPDX-License-Identifier: Apache-2.0
#include "sync.hpp"

#include <rakia/rakia.h>

#include <cmath>
#include <cstring>
#include <limits>
#include <nlohmann/json.hpp>

namespace rakia {

using json = nlohmann::json;

namespace {

[[noreturn]] void bad(const std::string& what) {
  throw SyncError(400, "invalid_batch", "The sync request is not valid (" + what + ").");
}

int hex_value(char c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  return -1;
}

bool is_hash_hex(const std::string& s) {
  if (s.size() != 2 * RAKIA_HASH_SIZE) return false;
  for (const char c : s) {
    if (hex_value(c) < 0) return false;
  }
  return true;
}

void hex_to_bytes(const std::string& hex, std::uint8_t* out) {
  for (std::size_t i = 0; i < hex.size() / 2; ++i) {
    out[i] = static_cast<std::uint8_t>((hex_value(hex[2 * i]) << 4) | hex_value(hex[2 * i + 1]));
  }
}

// contains() then at(): references only, which GCC's null-dereference
// analysis can follow (find() iterators it cannot).
const json& field(const json& j, const char* name) {
  if (!j.is_object() || !j.contains(name)) bad(name);
  return j.at(name);
}

std::string uuid_field(const json& j, const char* name) {
  const json& v = field(j, name);
  if (!v.is_string() || !uuid_bytes(v.get<std::string>())) bad(name);
  return v.get<std::string>();
}

std::string text_field(const json& j, const char* name, std::size_t max_len) {
  const json& v = field(j, name);
  if (!v.is_string()) bad(name);
  auto s = v.get<std::string>();
  if (s.empty() || s.size() > max_len) bad(name);
  return s;
}

std::int64_t int_field(const json& j, const char* name, std::int64_t lo, std::int64_t hi) {
  const json& f = field(j, name);
  if (!f.is_number_integer()) bad(name);
  const auto v = f.get<std::int64_t>();
  if (v < lo || v > hi) bad(name);
  return v;
}

// 2000-01-01 to 2100-01-01, in microseconds: rejects nonsense timestamps.
constexpr std::int64_t kMinUs = 946'684'800'000'000;
constexpr std::int64_t kMaxUs = 4'102'444'800'000'000;

}  // namespace

std::optional<std::string> uuid_bytes(const std::string& text) {
  if (text.size() != 36) return std::nullopt;
  std::string out;
  out.reserve(16);
  int high = -1;
  for (std::size_t i = 0; i < text.size(); ++i) {
    const char c = text[i];
    if (i == 8 || i == 13 || i == 18 || i == 23) {
      if (c != '-') return std::nullopt;
      continue;
    }
    const int v = hex_value(c);
    if (v < 0) return std::nullopt;
    if (high < 0) {
      high = v;
    } else {
      out.push_back(static_cast<char>((high << 4) | v));
      high = -1;
    }
  }
  return out;
}

SyncBatch parse_sync_batch(const json& body) {
  if (!body.is_object()) bad("body");
  SyncBatch b;
  b.batch_id = uuid_field(body, "batch_id");
  b.client_id = uuid_field(body, "client_id");
  b.subject_id = uuid_field(body, "subject_id");
  const json& mission = field(body, "mission");
  if (!mission.is_object()) bad("mission");
  b.mission_id = uuid_field(mission, "id");
  b.mission_name = text_field(mission, "name", 200);
  b.mission_start_us = int_field(mission, "start_at_us", kMinUs, kMaxUs);
  b.planned_days = static_cast<int>(int_field(mission, "planned_days", 1, 3650));

  const json& records = field(body, "records");
  if (!records.is_array() || records.empty()) bad("records");
  if (records.size() > kMaxSyncRecords) {
    throw SyncError(400, "batch_too_large",
                    "A sync batch may carry at most " + std::to_string(kMaxSyncRecords) +
                        " records.");
  }
  for (const auto& r : records) {
    if (!r.is_object()) bad("record");
    SyncRecord rec;
    rec.id = uuid_field(r, "id");
    rec.metric_code = text_field(r, "metric_code", RAKIA_MAX_CODE_LEN);
    rec.unit = text_field(r, "unit", RAKIA_MAX_UNIT_LEN);
    const json& value = field(r, "value");
    if (!value.is_number()) bad("value");
    rec.value = value.get<double>();
    if (!std::isfinite(rec.value)) bad("value");
    rec.observed_at_us = int_field(r, "observed_at_us", kMinUs, kMaxUs);
    rec.method = static_cast<int>(int_field(r, "method", 1, 4));
    rec.provenance = static_cast<int>(int_field(r, "provenance", 1, 3));
    if (rec.provenance == RAKIA_PROVENANCE_SIMULATED) {
      throw SyncError(400, "simulated_data",
                      "Simulated measurements are never synced to the server.");
    }
    rec.quality_flags = static_cast<int>(int_field(r, "quality_flags", 0, 0x7fffffff));
    rec.client_seq = int_field(r, "client_seq", 1, std::numeric_limits<std::int64_t>::max() - 1);
    rec.prev_hash = text_field(r, "prev_hash", 64);
    rec.hash = text_field(r, "hash", 64);
    if (!is_hash_hex(rec.prev_hash) || !is_hash_hex(rec.hash)) bad("hash");
    if (r.contains("supersedes_id") && !r.at("supersedes_id").is_null()) {
      rec.supersedes_id = uuid_field(r, "supersedes_id");
    }
    b.records.push_back(std::move(rec));
  }
  return b;
}

void verify_batch(const SyncBatch& batch) {
  const auto subject = uuid_bytes(batch.subject_id);
  if (!subject) bad("subject_id");
  const SyncRecord* previous = nullptr;
  for (const auto& r : batch.records) {
    if (previous != nullptr &&
        (r.client_seq != previous->client_seq + 1 || r.prev_hash != previous->hash)) {
      throw SyncError(400, "chain_broken",
                      "The records in the batch do not form one continuous chain.");
    }
    const auto id = uuid_bytes(r.id);
    if (!id) bad("id");
    rakia_record rec{};
    std::memcpy(rec.id, id->data(), 16);
    std::memcpy(rec.subject_id, subject->data(), 16);
    rec.metric_code = r.metric_code.c_str();
    rec.value = r.value;
    rec.unit = r.unit.c_str();
    rec.observed_at_us = r.observed_at_us;
    rec.method = static_cast<std::uint8_t>(r.method);
    rec.provenance = static_cast<std::uint8_t>(r.provenance);
    rec.client_seq = static_cast<std::uint64_t>(r.client_seq);
    hex_to_bytes(r.prev_hash, rec.prev_hash);
    std::uint8_t expected[RAKIA_HASH_SIZE];
    std::uint8_t sent[RAKIA_HASH_SIZE];
    hex_to_bytes(r.hash, sent);
    if (rakia_record_hash(&rec, expected) != RAKIA_OK ||
        std::memcmp(expected, sent, RAKIA_HASH_SIZE) != 0) {
      throw SyncError(400, "hash_mismatch",
                      "A record does not match its hash (sequence " +
                          std::to_string(r.client_seq) + ").");
    }
    previous = &r;
  }
}

}  // namespace rakia
