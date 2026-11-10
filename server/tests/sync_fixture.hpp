// SPDX-License-Identifier: Apache-2.0
//
// Builds sync batches the way a device does: each record hashed by librakia
// and chained to the one before.
#pragma once

#include <rakia/rakia.h>

#include <cstring>
#include <nlohmann/json.hpp>
#include <string>

#include "security.hpp"
#include "sync.hpp"

namespace rk {

inline std::string hex(const std::uint8_t* bytes, std::size_t n) {
  static constexpr char digits[] = "0123456789abcdef";
  std::string out;
  for (std::size_t i = 0; i < n; ++i) {
    out.push_back(digits[bytes[i] >> 4]);
    out.push_back(digits[bytes[i] & 0x0f]);
  }
  return out;
}

/// A device's record under construction.
struct Device {
  std::string client_id = rakia::new_uuid_v7();
  std::string mission_id = rakia::new_uuid_v7();
  std::string subject_id = rakia::new_uuid_v7();
  std::int64_t seq = 0;
  std::string last_hash = std::string(64, '0');

  /// The next record of the chain, as the JSON the app sends.
  nlohmann::json record(const std::string& metric, double value, const std::string& unit,
                        int provenance = RAKIA_PROVENANCE_REAL) {
    const auto id = rakia::new_uuid_v7();
    rakia_record rec{};
    std::memcpy(rec.id, rakia::uuid_bytes(id)->data(), 16);
    std::memcpy(rec.subject_id, rakia::uuid_bytes(subject_id)->data(), 16);
    rec.metric_code = metric.c_str();
    rec.value = value;
    rec.unit = unit.c_str();
    rec.observed_at_us = 1'794'225'600'000'000 + seq * 86'400'000'000;  // 2026-11-09 + days
    rec.method = RAKIA_METHOD_MANUAL;
    rec.provenance = static_cast<std::uint8_t>(provenance);
    rec.client_seq = static_cast<std::uint64_t>(++seq);
    for (std::size_t i = 0; i < RAKIA_HASH_SIZE; ++i) {
      rec.prev_hash[i] = static_cast<std::uint8_t>(
          std::stoi(last_hash.substr(2 * i, 2), nullptr, 16));
    }
    std::uint8_t out[RAKIA_HASH_SIZE];
    if (rakia_record_hash(&rec, out) != RAKIA_OK) throw std::runtime_error("hash failed");
    nlohmann::json j = {{"id", id},
                        {"metric_code", metric},
                        {"value", value},
                        {"unit", unit},
                        {"observed_at_us", rec.observed_at_us},
                        {"method", RAKIA_METHOD_MANUAL},
                        {"provenance", provenance},
                        {"quality_flags", 0},
                        {"client_seq", seq},
                        {"prev_hash", last_hash},
                        {"hash", hex(out, RAKIA_HASH_SIZE)}};
    last_hash = j["hash"].get<std::string>();
    return j;
  }

  nlohmann::json batch(nlohmann::json records) const {
    return {{"batch_id", rakia::new_uuid_v7()},
            {"client_id", client_id},
            {"subject_id", subject_id},
            {"mission",
             {{"id", mission_id},
              {"name", "My health record"},
              {"start_at_us", 1'794'182'400'000'000},
              {"planned_days", 365}}},
            {"records", std::move(records)}};
  }
};

}  // namespace rk
