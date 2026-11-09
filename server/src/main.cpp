// SPDX-License-Identifier: Apache-2.0
//
// rakia-api: RAKIA's HTTP API. Configuration comes from environment
// variables (see .env.example). For local development only, ./.env in the
// working directory is read first and the process environment wins; when
// RAKIA_ENV is set to staging or production no file is read at all, so
// deployed instances take settings only from their platform.
#include <atomic>
#include <chrono>
#include <csignal>
#include <memory>
#include <thread>

#include "app.hpp"
#include "config.hpp"
#include "log.hpp"
#include "pg_store.hpp"

namespace {
std::atomic<bool> g_stop{false};
extern "C" void on_signal(int) { g_stop = true; }

// A fixed path: the location of configuration is never taken from input.
constexpr const char* kDevEnvFile = ".env";
}  // namespace

int main() {
  rakia::Config config;
  try {
    const auto env = rakia::process_environment();
    const auto mode = env.find("RAKIA_ENV");
    const bool development = mode == env.end() || mode->second == "development";
    config = rakia::load_config(
        development ? rakia::read_env_file(kDevEnvFile) : rakia::EnvMap{}, env);
  } catch (const rakia::ConfigError& e) {
    rakia::log::error("configuration error", {{"detail", e.what()}});
    return 2;
  }
  rakia::log::info("starting rakia-api", {{"version", RAKIA_API_VERSION},
                                          {"config", config.describe()}});

  rakia::PgStore store(config);
  rakia::GoogleKeys google_keys;
  std::unique_ptr<rakia::TokenVerifier> verifier;
  if (config.firebase_project_id.empty()) {
    rakia::log::warn("sign-in is not configured (RAKIA_FIREBASE_PROJECT_ID is empty); "
                     "authenticated endpoints answer 503");
  } else if (!config.firebase_auth_emulator_host.empty()) {
    // Configuration allows this only in development.
    rakia::log::warn("accepting unsigned tokens from the Firebase Auth emulator",
                     {{"emulator", config.firebase_auth_emulator_host}});
    verifier = std::make_unique<rakia::EmulatorVerifier>(config.firebase_project_id);
  } else {
    verifier = std::make_unique<rakia::FirebaseVerifier>(config.firebase_project_id, google_keys);
  }
  rakia::CloudflareSiteverify siteverify;
  std::unique_ptr<rakia::TurnstileGuard> turnstile;
  if (config.turnstile_secret.empty()) {
    rakia::log::warn(config.environment == rakia::Environment::development
                         ? "turnstile is not configured; accounts are created unchecked"
                         : "turnstile is not configured; new accounts are refused");
  } else {
    turnstile = std::make_unique<rakia::TurnstileGuard>(config, siteverify);
  }
  rakia::NoaaSwpc noaa;
  rakia::SpaceWeatherService space_weather(noaa);
  rakia::App app(config, store, verifier.get(), {}, &space_weather, turnstile.get());
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
