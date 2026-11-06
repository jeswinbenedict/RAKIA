// SPDX-License-Identifier: Apache-2.0
#include "rate_limit.hpp"

#include <algorithm>
#include <cmath>
#include <sstream>
#include <vector>

namespace rakia {

RateLimiter::RateLimiter(std::uint32_t per_minute, Clock clock, std::size_t max_keys)
    : capacity_(static_cast<double>(per_minute)),
      per_second_(static_cast<double>(per_minute) / 60.0),
      clock_(clock ? std::move(clock) : Clock([] { return std::chrono::steady_clock::now(); })),
      max_keys_(max_keys) {}

RateLimiter::Decision RateLimiter::check(const std::string& key) {
  const auto now = clock_();
  const std::lock_guard<std::mutex> lock(mutex_);
  auto it = buckets_.find(key);
  if (it == buckets_.end()) {
    if (buckets_.size() >= max_keys_) evict_idle(now);
    it = buckets_.emplace(key, Bucket{capacity_, now}).first;
  }
  auto& b = it->second;
  const double elapsed = std::chrono::duration<double>(now - b.updated).count();
  b.tokens = std::min(capacity_, b.tokens + elapsed * per_second_);
  b.updated = now;
  if (b.tokens >= 1.0) {
    b.tokens -= 1.0;
    return {true, 0};
  }
  const double wait = (1.0 - b.tokens) / per_second_;
  return {false, static_cast<std::uint32_t>(std::max(1.0, std::ceil(wait)))};
}

void RateLimiter::evict_idle(std::chrono::steady_clock::time_point now) {
  // Drop buckets that have refilled completely: they hold no state worth
  // keeping. If every client is active, drop the stalest half.
  for (auto it = buckets_.begin(); it != buckets_.end();) {
    const double elapsed = std::chrono::duration<double>(now - it->second.updated).count();
    if (it->second.tokens + elapsed * per_second_ >= capacity_) {
      it = buckets_.erase(it);
    } else {
      ++it;
    }
  }
  if (buckets_.size() >= max_keys_) {
    std::vector<std::pair<std::chrono::steady_clock::time_point, std::string>> ages;
    ages.reserve(buckets_.size());
    for (const auto& [k, b] : buckets_) ages.emplace_back(b.updated, k);
    const auto half = ages.begin() + static_cast<std::ptrdiff_t>(ages.size() / 2);
    std::nth_element(ages.begin(), half, ages.end());
    for (auto i = ages.begin(); i != half; ++i) buckets_.erase(i->second);
  }
}

std::size_t RateLimiter::tracked_keys() const {
  const std::lock_guard<std::mutex> lock(mutex_);
  return buckets_.size();
}

std::string client_address(const std::string& socket_addr, const std::string& forwarded_for,
                           std::uint32_t trusted_hops) {
  if (trusted_hops == 0 || forwarded_for.empty()) return socket_addr;
  std::vector<std::string> hops;
  std::istringstream in(forwarded_for);
  for (std::string item; std::getline(in, item, ',');) {
    const auto first = item.find_first_not_of(" \t");
    if (first == std::string::npos) continue;
    hops.push_back(item.substr(first, item.find_last_not_of(" \t") - first + 1));
  }
  // The last proxy appended the address it saw; trusting N proxies means
  // the Nth entry from the right is the client.
  if (hops.size() < trusted_hops) return socket_addr;
  return hops[hops.size() - trusted_hops];
}

}  // namespace rakia
