// SPDX-License-Identifier: Apache-2.0
#pragma once

#include <optional>
#include <string>
#include <vector>

namespace rakia {

/// Cross-origin rules: only origins on the allow-list, compared exactly.
class Cors {
 public:
  explicit Cors(std::vector<std::string> allowed) : allowed_(std::move(allowed)) {}

  [[nodiscard]] bool allows(const std::string& origin) const;

  /// Response headers for an actual request from [origin]. Empty when the
  /// origin is absent or not allowed (the browser then blocks the read).
  [[nodiscard]] std::vector<std::pair<std::string, std::string>> response_headers(
      const std::optional<std::string>& origin) const;

  /// Headers answering a preflight, or nullopt when it must be refused:
  /// an origin not on the list, a method other than GET or POST, or a
  /// request header outside the allowed set.
  [[nodiscard]] std::optional<std::vector<std::pair<std::string, std::string>>> preflight(
      const std::string& origin, const std::string& method,
      const std::string& request_headers) const;

  static constexpr const char* allowed_methods = "GET, POST";
  static constexpr const char* allowed_headers =
      "Authorization, Content-Type, X-Turnstile-Token, X-Request-Id";

 private:
  std::vector<std::string> allowed_;
};

}  // namespace rakia
