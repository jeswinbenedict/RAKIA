// SPDX-License-Identifier: Apache-2.0
//
// rakia-api: RAKIA's HTTP API. Configuration comes from environment
// variables (see .env.example); for local development, a .env file in the
// working directory or at RAKIA_ENV_FILE is read first and the process
// environment wins.
#include <atomic>
#include <chrono>
#include <csignal>
#include <cstdlib>
#include <thread>

#include "app.hpp"
#include "config.hpp"
#include "log.hpp"
#include "pg_store.hpp"

namespace {
std::atomic<bool> g_stop{false};
extern "C" void on_signal(int) { g_stop = true; }

std::string env_file_path() {
#if defined(_MSC_VER)
  char* value = nullptr;
  std::size_t len = 0;
  std::string path = ".env";
  if (_dupenv_s(&value, &len, "RAKIA_ENV_FILE") == 0 && value != nullptr) {
    path = value;
    std::free(value);
  }
  return path;
#else
  const char* value = std::getenv("RAKIA_ENV_FILE");
  return value ? value : ".env";
#endif
}
}  // namespace

int main() {
  rakia::Config config;
  try {
    config = rakia::load_config(rakia::read_env_file(env_file_path()),
                                rakia::process_environment());
  } catch (const rakia::ConfigError& e) {
    rakia::log::error("configuration error", {{"detail", e.what()}});
    return 2;
  }
  rakia::log::info("starting rakia-api", {{"version", RAKIA_API_VERSION},
                                          {"config", config.describe()}});

  rakia::PgStore store(config);
  rakia::App app(config, store);
  auto& server = app.server();

  std::signal(SIGINT, on_signal);
  std::signal(SIGTERM, on_signal);
  // Signal handlers may only set a flag; this thread turns it into a clean
  // stop, letting in-flight requests finish.
  std::thread watcher([&server] {
    while (!g_stop) std::this_thread::sleep_for(std::chrono::milliseconds(100));
    server.stop();
  });

  if (!server.bind_to_port(config.api_host, config.api_port)) {
    rakia::log::error("cannot listen", {{"host", config.api_host}, {"port", config.api_port}});
    g_stop = true;
    watcher.join();
    return 1;
  }
  rakia::log::info("listening", {{"host", config.api_host}, {"port", config.api_port}});
  server.listen_after_bind();
  g_stop = true;
  watcher.join();
  rakia::log::info("stopped");
  return 0;
}
