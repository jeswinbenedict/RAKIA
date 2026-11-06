// SPDX-License-Identifier: Apache-2.0
#pragma once

#include <nlohmann/json.hpp>
#include <string_view>

namespace rakia::log {

/// Writes one JSON object per line to stderr (Cloud Logging reads
/// `severity` and `message`). Thread-safe. Never pass secrets, tokens,
/// request bodies or health data.
void write(std::string_view severity, std::string_view message, nlohmann::json fields = {});

inline void info(std::string_view message, nlohmann::json fields = {}) {
  write("INFO", message, std::move(fields));
}
inline void warn(std::string_view message, nlohmann::json fields = {}) {
  write("WARNING", message, std::move(fields));
}
inline void error(std::string_view message, nlohmann::json fields = {}) {
  write("ERROR", message, std::move(fields));
}

/// Turns logging off (tests).
void set_enabled(bool enabled);

}  // namespace rakia::log
