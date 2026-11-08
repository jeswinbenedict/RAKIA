// SPDX-License-Identifier: Apache-2.0
#include "security.hpp"

#include <array>
#include <chrono>
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

std::string new_uuid_v7() {
  thread_local std::random_device rd;
  std::array<std::uint8_t, 16> b{};
  const auto ms = static_cast<std::uint64_t>(
      std::chrono::duration_cast<std::chrono::milliseconds>(
          std::chrono::system_clock::now().time_since_epoch())
          .count());
  for (int i = 0; i < 6; ++i) b[static_cast<std::size_t>(i)] = static_cast<std::uint8_t>(ms >> (8 * (5 - i)));
  for (std::size_t i = 6; i < 16; i += 4) {
    const std::uint32_t r = rd();
    for (std::size_t j = 0; j < 4 && i + j < 16; ++j) b[i + j] = static_cast<std::uint8_t>(r >> (8 * j));
  }
  b[6] = static_cast<std::uint8_t>(0x70u | (b[6] & 0x0Fu));
  b[8] = static_cast<std::uint8_t>(0x80u | (b[8] & 0x3Fu));
  static constexpr char hex[] = "0123456789abcdef";
  std::string out;
  out.reserve(36);
  for (std::size_t i = 0; i < 16; ++i) {
    if (i == 4 || i == 6 || i == 8 || i == 10) out.push_back('-');
    out.push_back(hex[b[i] >> 4]);
    out.push_back(hex[b[i] & 0x0Fu]);
  }
  return out;
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
