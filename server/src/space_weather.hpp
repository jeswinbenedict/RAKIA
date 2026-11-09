// SPDX-License-Identifier: Apache-2.0
//
// Live space-radiation environment from the NOAA Space Weather Prediction
// Center (SWPC): GOES integral proton flux (>=10 MeV), the current NOAA
// solar radiation storm level (S-scale) and the planetary K index.
//
// This describes the environment near Earth (geostationary orbit), not the
// dose received by any crew member. It is context for decisions such as
// EVA planning, never a measurement of a person.
#pragma once

#include <chrono>
#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

namespace rakia {

/// A feed was unreachable or did not have the documented shape.
class SpaceWeatherError : public std::runtime_error {
 public:
  using std::runtime_error::runtime_error;
};

struct ProtonPoint {
  std::string time;  // ISO 8601, UTC, as published
  double flux = 0;   // particles / (cm^2 s sr), "pfu"
};

struct SpaceWeather {
  /// >=10 MeV integral proton flux from the primary GOES satellite, oldest
  /// first. NOAA's S1 threshold is 10 pfu in this channel.
  std::vector<ProtonPoint> protons_10mev;
  int satellite = 0;
  /// Current NOAA solar radiation storm level, 0 (none) to 5 (extreme).
  int s_level = 0;
  std::string s_text;
  std::string scales_time;  // ISO 8601, UTC
  /// Latest observed planetary K index (0 to 9) and its 3-hour slot.
  double kp = 0;
  std::string kp_time;
  /// When RAKIA retrieved the feeds (Unix seconds).
  std::int64_t retrieved_at = 0;
};

// Parsers for the three published JSON documents. Each validates the shape
// and value ranges and throws SpaceWeatherError otherwise.
std::vector<ProtonPoint> parse_protons_10mev(const std::string& body, int& satellite);
void parse_noaa_scales(const std::string& body, SpaceWeather& out);
void parse_planetary_kp(const std::string& body, SpaceWeather& out);

/// Where snapshots come from.
class SpaceWeatherSource {
 public:
  virtual ~SpaceWeatherSource() = default;
  /// A fresh snapshot. Throws SpaceWeatherError when it cannot be had.
  virtual SpaceWeather fetch() = 0;
};

/// The live NOAA SWPC feeds, over HTTPS with certificate verification.
class NoaaSwpc final : public SpaceWeatherSource {
 public:
  static constexpr const char* kHost = "services.swpc.noaa.gov";
  static constexpr const char* kProtons = "/json/goes/primary/integral-protons-1-day.json";
  static constexpr const char* kScales = "/products/noaa-scales.json";
  static constexpr const char* kKp = "/products/noaa-planetary-k-index.json";
  SpaceWeather fetch() override;
};

/// Serves the latest snapshot. NOAA publishes every five minutes, so a
/// snapshot is reused for five minutes, and a failed refresh is retried at
/// most once a minute. When refreshing fails, the previous snapshot is
/// served, marked stale, for up to six hours; after that, nothing is.
class SpaceWeatherService {
 public:
  using Clock = std::function<std::chrono::steady_clock::time_point()>;
  using WallClock = std::function<std::int64_t()>;
  static constexpr std::chrono::minutes kFreshFor{5};
  static constexpr std::chrono::minutes kRetryEvery{1};
  static constexpr std::chrono::hours kServeStaleFor{6};

  explicit SpaceWeatherService(SpaceWeatherSource& source, Clock clock = {},
                               WallClock wall = {});

  struct Result {
    SpaceWeather data;
    bool stale = false;
  };
  /// The snapshot to serve. Throws SpaceWeatherError when there is none.
  Result current();

 private:
  SpaceWeatherSource& source_;
  Clock now_;
  WallClock wall_;
  std::mutex mutex_;
  std::optional<SpaceWeather> last_;
  std::chrono::steady_clock::time_point fetched_{};
  std::chrono::steady_clock::time_point attempted_{};
  bool attempted_once_ = false;
};

/// Unix seconds as "YYYY-MM-DDTHH:MM:SSZ".
std::string iso8601_utc(std::int64_t unix_seconds);

}  // namespace rakia
