// SPDX-License-Identifier: Apache-2.0
#pragma once

#include <chrono>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <mutex>
#include <string>
#include <unordered_map>

namespace rakia {

/// A token bucket per client key: [per_minute] requests a minute, with
/// bursts up to the same number. In memory, per instance: behind several
/// instances each enforces its own limit. Thread-safe.
class RateLimiter {
 public:
  using Clock = std::function<std::chrono::steady_clock::time_point()>;

  explicit RateLimiter(std::uint32_t per_minute, Clock clock = {}, std::size_t max_keys = 100000);

  struct Decision {
    bool allowed;
    /// When refused: seconds until a request would be allowed.
    std::uint32_t retry_after_s;
  };

  Decision check(const std::string& key);

  [[nodiscard]] std::size_t tracked_keys() const;

 private:
  struct Bucket {
    double tokens;
    std::chrono::steady_clock::time_point updated;
  };

  void evict_idle(std::chrono::steady_clock::time_point now);

  double capacity_;
  double per_second_;
  Clock clock_;
  std::size_t max_keys_;
  mutable std::mutex mutex_;
  std::unordered_map<std::string, Bucket> buckets_;
};

/// The client address to rate-limit: the socket address, or with
/// [trusted_hops] proxies in front, the address they recorded in
/// X-Forwarded-For (counting from the right, as each proxy appends).
std::string client_address(const std::string& socket_addr, const std::string& forwarded_for,
                           std::uint32_t trusted_hops);

}  // namespace rakia
