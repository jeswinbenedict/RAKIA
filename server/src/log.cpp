// SPDX-License-Identifier: Apache-2.0
#include "log.hpp"

#include <atomic>
#include <chrono>
#include <cstdio>
#include <ctime>
#include <mutex>
#include <string>

namespace rakia::log {
namespace {
std::mutex g_mutex;
std::atomic<bool> g_enabled{true};

std::string utc_now() {
  using namespace std::chrono;
  const auto now = system_clock::now();
  const auto secs = system_clock::to_time_t(now);
  const auto ms = duration_cast<milliseconds>(now.time_since_epoch()).count() % 1000;
  std::tm tm{};
#if defined(_WIN32)
  gmtime_s(&tm, &secs);
#else
  gmtime_r(&secs, &tm);
#endif
  char buf[32];
  std::strftime(buf, sizeof buf, "%Y-%m-%dT%H:%M:%S", &tm);
  char out[40];
  std::snprintf(out, sizeof out, "%s.%03dZ", buf, static_cast<int>(ms));
  return out;
}
}  // namespace

void set_enabled(bool enabled) { g_enabled = enabled; }

void write(std::string_view severity, std::string_view message, nlohmann::json fields) {
  if (!g_enabled) return;
  nlohmann::json line = fields.is_object() ? std::move(fields) : nlohmann::json::object();
  line["time"] = utc_now();
  line["severity"] = severity;
  line["message"] = message;
  // Replace invalid UTF-8 rather than throwing on odd input.
  const auto text = line.dump(-1, ' ', false, nlohmann::json::error_handler_t::replace);
  const std::lock_guard<std::mutex> lock(g_mutex);
  std::fputs(text.c_str(), stderr);
  std::fputc('\n', stderr);
  std::fflush(stderr);
}

}  // namespace rakia::log
