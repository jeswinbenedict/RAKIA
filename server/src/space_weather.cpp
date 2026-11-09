// SPDX-License-Identifier: Apache-2.0
#include "space_weather.hpp"

#include <httplib.h>

#include <cmath>
#include <ctime>
#include <nlohmann/json.hpp>

#include "log.hpp"

namespace rakia {
namespace {

using json = nlohmann::json;

json parse(const std::string& body, const char* what) {
  json j = json::parse(body, nullptr, /*allow_exceptions=*/false);
  if (j.is_discarded()) throw SpaceWeatherError(std::string(what) + ": not JSON");
  return j;
}

/// "YYYY-MM-DDTHH:MM:SS" with an optional trailing "Z" (as NOAA publishes).
bool is_timestamp(const std::string& s) {
  if (s.size() != 19 && !(s.size() == 20 && s.back() == 'Z')) return false;
  for (std::size_t i = 0; i < 19; ++i) {
    const char c = s[i];
    const bool sep = i == 4 || i == 7 || i == 10 || i == 13 || i == 16;
    if (sep) {
      const char want = i == 10 ? 'T' : (i < 10 ? '-' : ':');
      if (c != want) return false;
    } else if (c < '0' || c > '9') {
      return false;
    }
  }
  return true;
}

std::string as_utc(std::string s) {
  if (s.back() != 'Z') s.push_back('Z');
  return s;
}

std::int64_t unix_now() {
  return std::chrono::duration_cast<std::chrono::seconds>(
             std::chrono::system_clock::now().time_since_epoch())
      .count();
}

}  // namespace

std::string iso8601_utc(std::int64_t unix_seconds) {
  const std::time_t t = static_cast<std::time_t>(unix_seconds);
  std::tm tm{};
#if defined(_WIN32)
  gmtime_s(&tm, &t);
#else
  gmtime_r(&t, &tm);
#endif
  char buf[32];
  std::strftime(buf, sizeof buf, "%Y-%m-%dT%H:%M:%SZ", &tm);
  return buf;
}

std::vector<ProtonPoint> parse_protons_10mev(const std::string& body, int& satellite) {
  const json j = parse(body, "proton flux");
  if (!j.is_array()) throw SpaceWeatherError("proton flux: not an array");
  std::vector<ProtonPoint> out;
  satellite = 0;
  for (const auto& row : j) {
    if (!row.is_object()) throw SpaceWeatherError("proton flux: row is not an object");
    const auto energy = row.find("energy");
    if (energy == row.end() || !energy->is_string() || energy->get<std::string>() != ">=10 MeV") {
      continue;  // other channels
    }
    const auto time = row.find("time_tag");
    const auto flux = row.find("flux");
    if (time == row.end() || !time->is_string() || !is_timestamp(time->get<std::string>())) {
      throw SpaceWeatherError("proton flux: bad time_tag");
    }
    if (flux == row.end() || !flux->is_number()) {
      throw SpaceWeatherError("proton flux: bad flux");
    }
    const double f = flux->get<double>();
    // Physically plausible: non-negative, and far below anything ever
    // observed (the largest events reach about 10^5 pfu).
    if (!std::isfinite(f) || f < 0 || f > 1e7) throw SpaceWeatherError("proton flux: out of range");
    const auto sat = row.find("satellite");
    if (sat != row.end() && sat->is_number_integer()) satellite = sat->get<int>();
    out.push_back({as_utc(time->get<std::string>()), f});
  }
  if (out.empty()) throw SpaceWeatherError("proton flux: no >=10 MeV data");
  return out;
}

void parse_noaa_scales(const std::string& body, SpaceWeather& out) {
  const json j = parse(body, "noaa scales");
  // "0" is the current observation; negative keys are past days, positive
  // keys are forecasts.
  const auto now = j.is_object() ? j.find("0") : j.end();
  if (now == j.end() || !now->is_object()) throw SpaceWeatherError("noaa scales: no current entry");
  const auto s = now->find("S");
  if (s == now->end() || !s->is_object()) throw SpaceWeatherError("noaa scales: no S scale");
  const auto scale = s->find("Scale");
  if (scale == s->end() || !scale->is_string()) throw SpaceWeatherError("noaa scales: bad S");
  const auto level = scale->get<std::string>();
  if (level.size() != 1 || level[0] < '0' || level[0] > '5') {
    throw SpaceWeatherError("noaa scales: S out of range");
  }
  out.s_level = level[0] - '0';
  const auto text = s->find("Text");
  out.s_text = text != s->end() && text->is_string() ? text->get<std::string>() : "";
  const auto date = now->find("DateStamp");
  const auto time = now->find("TimeStamp");
  if (date == now->end() || time == now->end() || !date->is_string() || !time->is_string()) {
    throw SpaceWeatherError("noaa scales: no timestamp");
  }
  const auto stamp = date->get<std::string>() + "T" + time->get<std::string>();
  if (!is_timestamp(stamp)) throw SpaceWeatherError("noaa scales: bad timestamp");
  out.scales_time = as_utc(stamp);
}

void parse_planetary_kp(const std::string& body, SpaceWeather& out) {
  const json j = parse(body, "kp");
  if (!j.is_array() || j.empty()) throw SpaceWeatherError("kp: no data");
  const auto& last = j.back();
  if (!last.is_object()) throw SpaceWeatherError("kp: row is not an object");
  const auto kp = last.find("Kp");
  const auto time = last.find("time_tag");
  if (kp == last.end() || !kp->is_number()) throw SpaceWeatherError("kp: bad Kp");
  if (time == last.end() || !time->is_string() || !is_timestamp(time->get<std::string>())) {
    throw SpaceWeatherError("kp: bad time_tag");
  }
  const double v = kp->get<double>();
  if (!std::isfinite(v) || v < 0 || v > 9) throw SpaceWeatherError("kp: out of range");
  out.kp = v;
  out.kp_time = as_utc(time->get<std::string>());
}

SpaceWeather NoaaSwpc::fetch() {
  httplib::SSLClient client(kHost, 443);
  client.enable_server_certificate_verification(true);
  client.set_connection_timeout(std::chrono::seconds(5));
  client.set_read_timeout(std::chrono::seconds(10));
  auto get = [&client](const char* path) {
    auto res = client.Get(path);
    // One retry for a dropped connection; an HTTP error answer is final.
    if (!res) res = client.Get(path);
    if (!res || res->status != 200) {
      log::warn("space weather feed unavailable",
                {{"path", path},
                 {"status", res ? res->status : 0},
                 {"error", res ? "" : httplib::to_string(res.error())}});
      throw SpaceWeatherError("feed unavailable");
    }
    return res->body;
  };
  SpaceWeather sw;
  sw.protons_10mev = parse_protons_10mev(get(kProtons), sw.satellite);
  parse_noaa_scales(get(kScales), sw);
  parse_planetary_kp(get(kKp), sw);
  sw.retrieved_at = unix_now();
  return sw;
}

SpaceWeatherService::SpaceWeatherService(SpaceWeatherSource& source, Clock clock, WallClock wall)
    : source_(source),
      now_(clock ? std::move(clock) : Clock([] { return std::chrono::steady_clock::now(); })),
      wall_(wall ? std::move(wall) : WallClock(unix_now)) {}

SpaceWeatherService::Result SpaceWeatherService::current() {
  const std::lock_guard<std::mutex> lock(mutex_);
  const auto now = now_();
  const bool fresh = last_ && now - fetched_ < kFreshFor;
  const bool may_try = !attempted_once_ || now - attempted_ >= kRetryEvery;
  if (!fresh && may_try) {
    attempted_ = now;
    attempted_once_ = true;
    try {
      last_ = source_.fetch();
      if (last_->retrieved_at == 0) last_->retrieved_at = wall_();
      fetched_ = now;
      return {*last_, false};
    } catch (const SpaceWeatherError& e) {
      log::warn("space weather refresh failed", {{"detail", e.what()}});
    }
  }
  if (last_ && now - fetched_ < kFreshFor) return {*last_, false};
  if (last_ && now - fetched_ < kServeStaleFor) return {*last_, true};
  throw SpaceWeatherError("no space weather data available");
}

}  // namespace rakia
