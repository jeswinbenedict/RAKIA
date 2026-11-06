// SPDX-License-Identifier: Apache-2.0
#include "security.hpp"

#include <array>
#include <cstdint>
#include <random>

namespace rakia {

std::vector<std::pair<std::string, std::string>> security_headers(Environment env) {
  std::vector<std::pair<std::string, std::string>> h{
      {"Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'; base-uri 'none'"},
      {"X-Content-Type-Options", "nosniff"},
      {"X-Frame-Options", "DENY"},
      {"Referrer-Policy", "no-referrer"},
      {"Cross-Origin-Opener-Policy", "same-origin"},
      {"Permissions-Policy", "camera=(), microphone=(), geolocation=(), interest-cohort=()"},
      // Responses may carry health data: never store them.
      {"Cache-Control", "no-store"},
  };
  if (env != Environment::development) {
    h.emplace_back("Strict-Transport-Security", "max-age=63072000; includeSubDomains");
  }
  return h;
}

std::string new_request_id() {
  // std::random_device draws from the operating system's CSPRNG on every
  // supported platform. thread_local: one generator per worker thread.
  thread_local std::random_device rd;
  static constexpr char hex[] = "0123456789abcdef";
  std::string id;
  id.reserve(32);
  for (int i = 0; i < 4; ++i) {
    std::uint32_t v = rd();
    for (int j = 0; j < 8; ++j) {
      id.push_back(hex[v & 0xFu]);
      v >>= 4;
    }
  }
  return id;
}

bool is_safe_request_id(const std::string& id) {
  if (id.size() < 8 || id.size() > 64) return false;
  for (const char c : id) {
    const bool ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') ||
                    c == '-';
    if (!ok) return false;
  }
  return true;
}

}  // namespace rakia
