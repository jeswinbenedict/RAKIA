// SPDX-License-Identifier: Apache-2.0
#pragma once

#include <httplib.h>

#include <memory>

#include "config.hpp"
#include "cors.hpp"
#include "firebase_auth.hpp"
#include "rate_limit.hpp"
#include "space_weather.hpp"
#include "store.hpp"
#include "turnstile.hpp"

namespace rakia {

/// Largest request body accepted (bytes).
inline constexpr std::size_t kMaxBodyBytes = 1u << 20;

/// The HTTP API: routes, security headers, CORS, rate limiting, request ids,
/// JSON errors and access logs, on top of a Store.
class App {
 public:
  /// [verifier] checks Firebase ID tokens; without one, endpoints that need
  /// a signed-in user answer 503 (sign-in not configured).
  /// [space_weather] serves the live radiation environment; without it,
  /// /v1/space-weather answers 503. [turnstile] guards account creation;
  /// without it, development creates accounts unchecked and every other
  /// environment refuses to create them.
  App(const Config& config, Store& store, const TokenVerifier* verifier = nullptr,
      RateLimiter::Clock clock = {}, SpaceWeatherService* space_weather = nullptr,
      const TurnstileGuard* turnstile = nullptr);

  httplib::Server& server() { return server_; }

 private:
  void routes();
  void sync_routes();
  /// The verified user of a request, or nullopt after answering 401/503.
  std::optional<VerifiedUser> authenticate(const httplib::Request& req,
                                           httplib::Response& res) const;

  Config config_;
  Store& store_;
  const TokenVerifier* verifier_;
  const TurnstileGuard* turnstile_;
  SpaceWeatherService* space_weather_;
  Cors cors_;
  RateLimiter limiter_;
  httplib::Server server_;
};

}  // namespace rakia
