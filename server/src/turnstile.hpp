// SPDX-License-Identifier: Apache-2.0
//
// Cloudflare Turnstile: bot friction before a RAKIA account is created. The
// app solves a challenge and sends the token; the API asks Cloudflare
// whether it is valid (siteverify, with the secret key), checks where and
// for what it was solved, and remembers its hash so it cannot be replayed.
// Turnstile is not identity; Firebase sign-in still decides who the user is.
#pragma once

#include <functional>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include "config.hpp"

namespace rakia {

/// Cloudflare's answer to a siteverify request.
struct SiteverifyResult {
  bool success = false;
  std::vector<std::string> error_codes;
  std::string hostname;
  std::string action;
  /// True when a Cloudflare testing secret answered (always-pass keys).
  bool testing_key = false;
};

/// Parses a siteverify response body. Throws std::runtime_error when it is
/// not the documented JSON object.
SiteverifyResult parse_siteverify(std::string_view body);

/// Asks Cloudflare whether a token is valid.
class SiteverifyClient {
 public:
  virtual ~SiteverifyClient() = default;
  /// Throws std::runtime_error when Cloudflare cannot be reached.
  virtual SiteverifyResult verify(const std::string& secret, const std::string& token,
                                  const std::string& remote_ip) = 0;
};

/// siteverify over HTTPS with certificate verification.
class CloudflareSiteverify final : public SiteverifyClient {
 public:
  static constexpr const char* kHost = "challenges.cloudflare.com";
  static constexpr const char* kPath = "/turnstile/v0/siteverify";
  SiteverifyResult verify(const std::string& secret, const std::string& token,
                          const std::string& remote_ip) override;
};

/// The outcome of checking a token, with a reason code that is safe to log.
struct TurnstileDecision {
  bool allowed = false;
  /// "ok", "missing", "too_long", "unavailable", "rejected", "testing_key",
  /// "wrong_hostname", "wrong_action" or "replayed".
  std::string reason;
};

/// The action the app names when it renders the widget for account creation.
inline constexpr const char* kCreateAccountAction = "create-account";

/// SHA-256 of a token, hex encoded: what the replay table stores.
std::string token_hash_hex(std::string_view token);

/// Applies RAKIA's rules to a token. [remember] records a token hash and
/// returns false if it was already recorded (a replay).
class TurnstileGuard {
 public:
  using Remember = std::function<bool(const std::string& hash_hex)>;

  TurnstileGuard(const Config& config, SiteverifyClient& client);

  TurnstileDecision check(const std::string& token, const std::string& remote_ip,
                          const Remember& remember) const;

  /// Longest token accepted (Cloudflare's tokens are at most 2048 bytes).
  static constexpr std::size_t kMaxTokenBytes = 2048;

 private:
  std::string secret_;
  std::vector<std::string> hostnames_;
  bool development_;
  SiteverifyClient& client_;
};

}  // namespace rakia
