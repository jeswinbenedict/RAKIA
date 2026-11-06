// SPDX-License-Identifier: Apache-2.0
#pragma once

#include <httplib.h>

#include <memory>

#include "config.hpp"
#include "cors.hpp"
#include "rate_limit.hpp"
#include "store.hpp"

namespace rakia {

/// Largest request body accepted (bytes).
inline constexpr std::size_t kMaxBodyBytes = 1u << 20;

/// The HTTP API: routes, security headers, CORS, rate limiting, request ids,
/// JSON errors and access logs, on top of a Store.
class App {
 public:
  App(const Config& config, Store& store, RateLimiter::Clock clock = {});

  httplib::Server& server() { return server_; }

 private:
  void routes();

  Config config_;
  Store& store_;
  Cors cors_;
  RateLimiter limiter_;
  httplib::Server server_;
};

}  // namespace rakia
