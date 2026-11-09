// SPDX-License-Identifier: Apache-2.0
#include "turnstile.hpp"

#include <httplib.h>
#include <openssl/evp.h>

#include <algorithm>
#include <array>
#include <chrono>
#include <nlohmann/json.hpp>
#include <stdexcept>

#include "log.hpp"

namespace rakia {

using json = nlohmann::json;

SiteverifyResult parse_siteverify(std::string_view body) {
  const json j = json::parse(body, nullptr, /*allow_exceptions=*/false);
  if (!j.is_object()) throw std::runtime_error("siteverify: not an object");
  const auto success = j.find("success");
  if (success == j.end() || !success->is_boolean()) {
    throw std::runtime_error("siteverify: no success field");
  }
  SiteverifyResult r;
  r.success = success->get<bool>();
  if (const auto e = j.find("error-codes"); e != j.end() && e->is_array()) {
    for (const auto& code : *e) {
      if (code.is_string()) r.error_codes.push_back(code.get<std::string>());
    }
  }
  if (const auto h = j.find("hostname"); h != j.end() && h->is_string()) {
    r.hostname = h->get<std::string>();
  }
  if (const auto a = j.find("action"); a != j.end() && a->is_string()) {
    r.action = a->get<std::string>();
  }
  if (const auto m = j.find("metadata"); m != j.end() && m->is_object()) {
    const auto t = m->find("result_with_testing_key");
    r.testing_key = t != m->end() && t->is_boolean() && t->get<bool>();
  }
  return r;
}

SiteverifyResult CloudflareSiteverify::verify(const std::string& secret,
                                              const std::string& token,
                                              const std::string& remote_ip) {
  httplib::SSLClient client(kHost, 443);
  client.enable_server_certificate_verification(true);
  client.set_connection_timeout(std::chrono::seconds(5));
  client.set_read_timeout(std::chrono::seconds(10));
  httplib::Params form{{"secret", secret}, {"response", token}};
  if (!remote_ip.empty()) form.emplace("remoteip", remote_ip);
  auto res = client.Post(kPath, form);
  // One retry for a dropped connection; an HTTP error answer is final.
  if (!res) res = client.Post(kPath, form);
  if (!res || res->status != 200) {
    log::warn("turnstile siteverify unavailable",
              {{"status", res ? res->status : 0},
               {"error", res ? "" : httplib::to_string(res.error())}});
    throw std::runtime_error("siteverify unavailable");
  }
  return parse_siteverify(res->body);
}

std::string token_hash_hex(std::string_view token) {
  std::array<unsigned char, EVP_MAX_MD_SIZE> digest{};
  unsigned int len = 0;
  if (EVP_Digest(token.data(), token.size(), digest.data(), &len, EVP_sha256(), nullptr) != 1 ||
      len != 32) {
    throw std::runtime_error("sha256 failed");
  }
  static constexpr char kHex[] = "0123456789abcdef";
  std::string out;
  out.reserve(64);
  for (unsigned int i = 0; i < len; ++i) {
    out.push_back(kHex[digest[i] >> 4]);
    out.push_back(kHex[digest[i] & 0x0f]);
  }
  return out;
}

TurnstileGuard::TurnstileGuard(const Config& config, SiteverifyClient& client)
    : secret_(config.turnstile_secret),
      hostnames_(config.turnstile_hostnames),
      development_(config.environment == Environment::development),
      client_(client) {}

TurnstileDecision TurnstileGuard::check(const std::string& token, const std::string& remote_ip,
                                        const Remember& remember) const {
  if (token.empty()) return {false, "missing"};
  if (token.size() > kMaxTokenBytes) return {false, "too_long"};
  SiteverifyResult r;
  try {
    r = client_.verify(secret_, token, remote_ip);
  } catch (const std::exception&) {
    return {false, "unavailable"};
  }
  if (!r.success) return {false, "rejected"};
  // An always-pass testing secret must never protect a real deployment.
  if (r.testing_key && !development_) return {false, "testing_key"};
  if (!r.testing_key &&
      std::find(hostnames_.begin(), hostnames_.end(), r.hostname) == hostnames_.end()) {
    return {false, "wrong_hostname"};
  }
  if (!r.action.empty() && r.action != kCreateAccountAction) return {false, "wrong_action"};
  // Cloudflare also refuses a second siteverify of the same token; the
  // replay table makes that independent of Cloudflare.
  if (!remember(token_hash_hex(token))) return {false, "replayed"};
  return {true, "ok"};
}

}  // namespace rakia
