// SPDX-License-Identifier: Apache-2.0
// Sync batches before the database: request validation, and verification
// of every record's hash and of the chain with librakia. A record altered
// in any hashed field is refused.
#include <nlohmann/json.hpp>

#include "log.hpp"
#include "rk_test.hpp"
#include "sync.hpp"
#include "sync_fixture.hpp"

using json = nlohmann::json;
using rakia::SyncError;

namespace {

std::string refusal(const json& body) {
  try {
    rakia::verify_batch(rakia::parse_sync_batch(body));
  } catch (const SyncError& e) {
    return e.code;
  }
  return "accepted";
}

json three(rk::Device& d) {
  return d.batch(json::array({d.record("heart_rate.resting", 58.0, "/min"),
                              d.record("sleep.duration", 7.25, "h"),
                              d.record("spo2", 97.5, "%")}));
}

}  // namespace

TEST("a batch hashed and chained by librakia is accepted") {
  rk::Device d;
  const auto body = three(d);
  const auto b = rakia::parse_sync_batch(body);
  CHECK_EQ(b.records.size(), std::size_t{3});
  CHECK_EQ(b.records[2].client_seq, std::int64_t{3});
  CHECK_EQ(refusal(body), std::string("accepted"));
}

TEST("a record altered in any hashed field is refused") {
  rk::Device d;
  const auto good = three(d);
  for (const auto& [field, value] :
       std::vector<std::pair<std::string, json>>{{"value", 59.0},
                                                 {"metric_code", "hrv.rmssd"},
                                                 {"unit", "ms"},
                                                 {"observed_at_us", 1'794'225'600'000'001},
                                                 {"method", 1},
                                                 {"provenance", 2},
                                                 {"id", rakia::new_uuid_v7()}}) {
    auto body = good;
    body["records"][0][field] = value;
    CHECK_EQ(refusal(body), std::string("hash_mismatch"));
  }
  // Another person's subject id does not match the hashes either.
  auto body = good;
  body["subject_id"] = rakia::new_uuid_v7();
  CHECK_EQ(refusal(body), std::string("hash_mismatch"));
}

TEST("a batch must be one continuous chain") {
  rk::Device d;
  auto body = three(d);
  auto records = body["records"];
  body["records"] = json::array({records[0], records[2]});
  CHECK_EQ(refusal(body), std::string("chain_broken"));
  body["records"] = json::array({records[1], records[0]});
  CHECK_EQ(refusal(body), std::string("chain_broken"));
}

TEST("simulated data is never accepted") {
  rk::Device d;
  const auto body =
      d.batch(json::array({d.record("heart_rate.resting", 58.0, "/min", RAKIA_PROVENANCE_SIMULATED)}));
  CHECK_EQ(refusal(body), std::string("simulated_data"));
}

TEST("malformed requests are refused before any work") {
  rk::Device d;
  const auto good = three(d);
  CHECK_EQ(refusal(json::array()), std::string("invalid_batch"));
  for (const char* field : {"batch_id", "client_id", "subject_id", "mission", "records"}) {
    auto body = good;
    body.erase(field);
    CHECK_EQ(refusal(body), std::string("invalid_batch"));
  }
  auto body = good;
  body["client_id"] = "not-a-uuid";
  CHECK_EQ(refusal(body), std::string("invalid_batch"));
  body = good;
  body["records"] = json::array();
  CHECK_EQ(refusal(body), std::string("invalid_batch"));
  body = good;
  body["records"][0]["hash"] = "abc";
  CHECK_EQ(refusal(body), std::string("invalid_batch"));
  body = good;
  body["records"][0]["value"] = "58";
  CHECK_EQ(refusal(body), std::string("invalid_batch"));
  body = good;
  body["records"][0]["client_seq"] = 0;
  CHECK_EQ(refusal(body), std::string("invalid_batch"));
  body = good;
  body["mission"]["planned_days"] = 0;
  CHECK_EQ(refusal(body), std::string("invalid_batch"));

  json many = json::array();
  rk::Device big;
  for (std::size_t i = 0; i <= rakia::kMaxSyncRecords; ++i) {
    many.push_back(big.record("heart_rate.resting", 58.0, "/min"));
  }
  CHECK_EQ(refusal(big.batch(many)), std::string("batch_too_large"));
}

TEST("UUIDs: canonical lower-case form only") {
  CHECK(rakia::uuid_bytes("0190b8f4-0000-7000-8000-000000000001").has_value());
  CHECK_EQ(rakia::uuid_bytes("0190b8f4-0000-7000-8000-000000000001")->size(), std::size_t{16});
  CHECK(!rakia::uuid_bytes("0190B8F4-0000-7000-8000-000000000001").has_value());
  CHECK(!rakia::uuid_bytes("0190b8f400007000800000000000000001").has_value());
  CHECK(!rakia::uuid_bytes("").has_value());
}

int main() {
  rakia::log::set_enabled(false);
  return rk::run("sync");
}
