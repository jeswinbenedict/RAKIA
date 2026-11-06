// SPDX-License-Identifier: Apache-2.0
// Rate limiting: bursts, refill, independence of clients, bounded memory,
// and which address is limited behind proxies.
#include <chrono>

#include "rate_limit.hpp"
#include "rk_test.hpp"

using namespace std::chrono_literals;
using rakia::RateLimiter;

namespace {
struct FakeClock {
  std::chrono::steady_clock::time_point now = std::chrono::steady_clock::time_point{} + 1h;
  RateLimiter::Clock fn() {
    return [this] { return now; };
  }
};
}  // namespace

TEST("allows a burst up to the limit, then refuses with Retry-After") {
  FakeClock clock;
  RateLimiter rl(60, clock.fn());
  for (int i = 0; i < 60; ++i) CHECK(rl.check("a").allowed);
  const auto d = rl.check("a");
  CHECK(!d.allowed);
  CHECK_EQ(d.retry_after_s, 1u);
}

TEST("refills at the configured rate") {
  FakeClock clock;
  RateLimiter rl(60, clock.fn());
  for (int i = 0; i < 60; ++i) rl.check("a");
  CHECK(!rl.check("a").allowed);
  clock.now += 1s;
  CHECK(rl.check("a").allowed);
  CHECK(!rl.check("a").allowed);
  clock.now += 10min;
  for (int i = 0; i < 60; ++i) CHECK(rl.check("a").allowed);
  CHECK(!rl.check("a").allowed);
}

TEST("clients are limited independently") {
  FakeClock clock;
  RateLimiter rl(2, clock.fn());
  CHECK(rl.check("a").allowed);
  CHECK(rl.check("a").allowed);
  CHECK(!rl.check("a").allowed);
  CHECK(rl.check("b").allowed);
}

TEST("Retry-After reflects a slow rate") {
  FakeClock clock;
  RateLimiter rl(1, clock.fn());
  CHECK(rl.check("a").allowed);
  CHECK_EQ(rl.check("a").retry_after_s, 60u);
}

TEST("memory stays bounded under many clients") {
  FakeClock clock;
  RateLimiter rl(10, clock.fn(), 100);
  for (int i = 0; i < 1000; ++i) rl.check("client-" + std::to_string(i));
  CHECK(rl.tracked_keys() <= 100);
  // Idle buckets are dropped first; a fresh client is still served.
  clock.now += 1h;
  CHECK(rl.check("late").allowed);
  CHECK(rl.tracked_keys() <= 100);
}

TEST("client address: the socket unless proxies are trusted") {
  using rakia::client_address;
  CHECK_EQ(client_address("10.0.0.1", "1.2.3.4", 0), std::string("10.0.0.1"));
  CHECK_EQ(client_address("10.0.0.1", "", 1), std::string("10.0.0.1"));
  // A client can prepend anything; only the entries proxies appended count.
  CHECK_EQ(client_address("10.0.0.1", "6.6.6.6, 1.2.3.4", 1), std::string("1.2.3.4"));
  CHECK_EQ(client_address("10.0.0.1", "6.6.6.6, 1.2.3.4, 10.1.1.1", 2), std::string("1.2.3.4"));
  CHECK_EQ(client_address("10.0.0.1", "1.2.3.4", 2), std::string("10.0.0.1"));
}

RK_MAIN("rate_limit")
