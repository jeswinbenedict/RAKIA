// SPDX-License-Identifier: Apache-2.0
// Live space weather: the NOAA SWPC parsers accept the published shapes and
// refuse anything else; the service caches, retries at most once a minute
// and serves the last good snapshot as stale for a bounded time; the HTTP
// endpoint reports source, timestamps and staleness. The documents below
// follow the published formats; their values are test inputs, not
// observations.
#include <chrono>
#include <cstdlib>
#include <nlohmann/json.hpp>
#include <thread>

#include "app.hpp"
#include "log.hpp"
#include "rk_test.hpp"

using namespace std::chrono_literals;
using json = nlohmann::json;
using rakia::SpaceWeatherError;

namespace {

const char* kProtons = R"([
  {"time_tag": "2026-11-08T10:50:00Z", "satellite": 18, "flux": 10.3, "energy": ">=1 MeV"},
  {"time_tag": "2026-11-08T10:50:00Z", "satellite": 18, "flux": 0.24, "energy": ">=10 MeV"},
  {"time_tag": "2026-11-08T10:55:00Z", "satellite": 18, "flux": 0.26, "energy": ">=10 MeV"},
  {"time_tag": "2026-11-08T10:55:00Z", "satellite": 18, "flux": 0.01, "energy": ">=100 MeV"}
])";

const char* kScales = R"({
  "-1": {"DateStamp": "2026-11-08", "TimeStamp": "00:00:00", "S": {"Scale": "1", "Text": "minor"}},
  "0": {"DateStamp": "2026-11-09", "TimeStamp": "10:45:00",
        "R": {"Scale": "0", "Text": "none"}, "S": {"Scale": "0", "Text": "none", "Prob": null},
        "G": {"Scale": "0", "Text": "none"}}
})";

const char* kKp = R"([
  {"time_tag": "2026-11-09T03:00:00", "Kp": 2.00, "a_running": 7, "station_count": 8},
  {"time_tag": "2026-11-09T06:00:00", "Kp": 2.33, "a_running": 9, "station_count": 8}
])";

rakia::SpaceWeather snapshot(double latest = 0.26) {
  rakia::SpaceWeather sw;
  sw.protons_10mev = {{"2026-11-09T10:50:00Z", 0.24}, {"2026-11-09T10:55:00Z", latest}};
  sw.satellite = 18;
  sw.s_level = 0;
  sw.s_text = "none";
  sw.scales_time = "2026-11-09T10:45:00Z";
  sw.kp = 2.33;
  sw.kp_time = "2026-11-09T06:00:00Z";
  sw.retrieved_at = 1'794'200'000;
  return sw;
}

/// A source whose next answer the test controls.
struct ScriptedSource final : rakia::SpaceWeatherSource {
  bool fail = false;
  int calls = 0;
  double flux = 0.26;
  rakia::SpaceWeather fetch() override {
    ++calls;
    if (fail) throw SpaceWeatherError("feed unavailable");
    return snapshot(flux);
  }
};

struct ManualClock {
  std::chrono::steady_clock::time_point t{std::chrono::hours(1000)};
  rakia::SpaceWeatherService::Clock fn() {
    return [this] { return t; };
  }
};

struct NoStore final : rakia::Store {
  int schema_version() override { return rakia::kExpectedSchemaVersion; }
  std::vector<rakia::MetricDefinition> metric_definitions() override { return {}; }
  std::optional<rakia::Account> find_account(const std::string&) override { return {}; }
  rakia::Account create_account(const std::string&) override { return {}; }
  bool remember_turnstile_token(const std::string&) override { return true; }
  rakia::SyncResult sync_batch(const std::string&, const rakia::SyncBatch&) override {
    return {};
  }
};

rakia::Config config() {
  rakia::Config c;
  c.cors_origins = {"https://app.example"};
  c.rate_limit_per_minute = 1000;
  c.db_host = c.db_name = c.db_password = "unused";
  c.db_user = "rakia_api";
  return c;
}

std::string last_cache_control;

json get(rakia::App& app, int& status) {
  const int port = app.server().bind_to_any_port("127.0.0.1");
  std::thread t([&app] { app.server().listen_after_bind(); });
  app.server().wait_until_ready();
  httplib::Client c("127.0.0.1", port);
  c.set_read_timeout(5s);
  const auto r = c.Get("/v1/space-weather");
  app.server().stop();
  t.join();
  status = r ? r->status : 0;
  if (r && r->status == 200) last_cache_control = r->get_header_value("Cache-Control");
  return r ? json::parse(r->body) : json();
}

bool network_tests() {
#if defined(_MSC_VER)
  char* v = nullptr;
  std::size_t n = 0;
  const bool on = _dupenv_s(&v, &n, "RAKIA_API_NETWORK_TESTS") == 0 && v != nullptr &&
                  std::string(v) == "1";
  std::free(v);
  return on;
#else
  const char* v = std::getenv("RAKIA_API_NETWORK_TESTS");
  return v != nullptr && std::string(v) == "1";
#endif
}

}  // namespace

TEST("proton flux: only the >=10 MeV channel, oldest first, in UTC") {
  int sat = 0;
  const auto p = rakia::parse_protons_10mev(kProtons, sat);
  CHECK_EQ(p.size(), std::size_t{2});
  CHECK_EQ(p.front().time, std::string("2026-11-08T10:50:00Z"));
  CHECK_EQ(p.back().flux, 0.26);
  CHECK_EQ(sat, 18);
}

TEST("proton flux: malformed documents are refused") {
  int sat = 0;
  CHECK_THROWS(SpaceWeatherError, rakia::parse_protons_10mev("not json", sat));
  CHECK_THROWS(SpaceWeatherError, rakia::parse_protons_10mev("{}", sat));
  CHECK_THROWS(SpaceWeatherError, rakia::parse_protons_10mev("[]", sat));
  CHECK_THROWS(SpaceWeatherError,
               rakia::parse_protons_10mev(
                   R"([{"time_tag":"2026-11-08T10:50:00Z","flux":-1,"energy":">=10 MeV"}])", sat));
  CHECK_THROWS(SpaceWeatherError,
               rakia::parse_protons_10mev(
                   R"([{"time_tag":"yesterday","flux":1,"energy":">=10 MeV"}])", sat));
  CHECK_THROWS(SpaceWeatherError,
               rakia::parse_protons_10mev(
                   R"([{"time_tag":"2026-11-08T10:50:00Z","flux":"1","energy":">=10 MeV"}])", sat));
}

TEST("NOAA scales: the current S level and its time") {
  rakia::SpaceWeather sw;
  rakia::parse_noaa_scales(kScales, sw);
  CHECK_EQ(sw.s_level, 0);
  CHECK_EQ(sw.s_text, std::string("none"));
  CHECK_EQ(sw.scales_time, std::string("2026-11-09T10:45:00Z"));
  CHECK_THROWS(SpaceWeatherError, rakia::parse_noaa_scales(R"({"-1":{}})", sw));
  CHECK_THROWS(SpaceWeatherError,
               rakia::parse_noaa_scales(
                   R"({"0":{"DateStamp":"2026-11-09","TimeStamp":"10:45:00","S":{"Scale":"7"}}})",
                   sw));
}

TEST("planetary K index: the latest value, within 0 to 9") {
  rakia::SpaceWeather sw;
  rakia::parse_planetary_kp(kKp, sw);
  CHECK_EQ(sw.kp, 2.33);
  CHECK_EQ(sw.kp_time, std::string("2026-11-09T06:00:00Z"));
  CHECK_THROWS(SpaceWeatherError, rakia::parse_planetary_kp("[]", sw));
  CHECK_THROWS(SpaceWeatherError,
               rakia::parse_planetary_kp(R"([{"time_tag":"2026-11-09T06:00:00","Kp":12}])", sw));
}

TEST("service: reuses a snapshot for five minutes, then refreshes") {
  ScriptedSource src;
  ManualClock clock;
  rakia::SpaceWeatherService svc(src, clock.fn());
  CHECK(!svc.current().stale);
  clock.t += 4min;
  svc.current();
  CHECK_EQ(src.calls, 1);
  clock.t += 2min;
  src.flux = 0.5;
  CHECK_EQ(svc.current().data.protons_10mev.back().flux, 0.5);
  CHECK_EQ(src.calls, 2);
}

TEST("service: when NOAA fails, the last snapshot is served as stale, for six hours") {
  ScriptedSource src;
  ManualClock clock;
  rakia::SpaceWeatherService svc(src, clock.fn());
  svc.current();
  src.fail = true;
  clock.t += 6min;
  CHECK(svc.current().stale);
  CHECK_EQ(src.calls, 2);
  // At most one retry a minute.
  clock.t += 30s;
  svc.current();
  CHECK_EQ(src.calls, 2);
  clock.t += 6h;
  CHECK_THROWS(SpaceWeatherError, svc.current());
  // Recovery as soon as NOAA answers again.
  src.fail = false;
  clock.t += 1min;
  CHECK(!svc.current().stale);
}

TEST("service: with no data ever retrieved, nothing is invented") {
  ScriptedSource src;
  src.fail = true;
  ManualClock clock;
  rakia::SpaceWeatherService svc(src, clock.fn());
  CHECK_THROWS(SpaceWeatherError, svc.current());
}

TEST("endpoint: source, timestamps, latest flux and S level") {
  NoStore store;
  ScriptedSource src;
  rakia::SpaceWeatherService svc(src);
  rakia::App app(config(), store, nullptr, {}, &svc);
  int status = 0;
  const auto j = get(app, status);
  CHECK_EQ(status, 200);
  CHECK_EQ(j["source"]["name"], "NOAA Space Weather Prediction Center");
  CHECK_EQ(j["source"]["satellite"], "GOES-18");
  CHECK_EQ(j["retrieved_at"], "2026-11-09T04:53:20Z");
  CHECK_EQ(j["stale"], false);
  CHECK_EQ(j["proton_flux_10mev"]["latest"]["flux"], 0.26);
  CHECK_EQ(j["proton_flux_10mev"]["points"].size(), std::size_t{2});
  CHECK_EQ(j["radiation_storm"]["scale"], "S0");
  CHECK_EQ(j["geomagnetic"]["kp"], 2.33);
  CHECK_EQ(last_cache_control, std::string("public, max-age=60"));
}

TEST("endpoint: 503 when unavailable or not configured, never invented data") {
  NoStore store;
  ScriptedSource src;
  src.fail = true;
  rakia::SpaceWeatherService svc(src);
  rakia::App down(config(), store, nullptr, {}, &svc);
  int status = 0;
  CHECK_EQ(get(down, status)["error"]["code"], "space_weather_unavailable");
  CHECK_EQ(status, 503);
  rakia::App none(config(), store);
  CHECK_EQ(get(none, status)["error"]["code"], "space_weather_not_configured");
  CHECK_EQ(status, 503);
}

TEST("live NOAA SWPC feeds parse (network; RAKIA_API_NETWORK_TESTS=1)") {
  if (!network_tests()) return;
  rakia::NoaaSwpc noaa;
  const auto sw = noaa.fetch();
  CHECK(!sw.protons_10mev.empty());
  CHECK(sw.s_level >= 0 && sw.s_level <= 5);
  CHECK(sw.kp >= 0 && sw.kp <= 9);
}

int main() {
  rakia::log::set_enabled(false);
  return rk::run("space_weather");
}
