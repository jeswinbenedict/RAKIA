// SPDX-License-Identifier: Apache-2.0
#include "app.hpp"

#include <cctype>
#include <chrono>
#include <exception>
#include <nlohmann/json.hpp>
#include <string>

#include "log.hpp"
#include "security.hpp"

namespace rakia {
namespace {

using json = nlohmann::json;
constexpr const char* kJson = "application/json; charset=utf-8";

// Per worker thread: when the current request started, for the access log.
thread_local std::chrono::steady_clock::time_point t_started;

std::string request_id(const httplib::Response& res) {
  return res.get_header_value("X-Request-Id");
}

void send(httplib::Response& res, int status, const json& body) {
  res.status = status;
  res.set_content(body.dump(), kJson);
}

void send_error(httplib::Response& res, int status, const std::string& code,
                const std::string& message) {
  send(res, status,
       {{"error", {{"code", code}, {"message", message}, {"request_id", request_id(res)}}}});
}

/// The bearer token of an Authorization header, or empty.
std::string bearer_token(const httplib::Request& req) {
  const auto h = req.get_header_value("Authorization");
  if (h.size() < 7) return {};
  std::string scheme = h.substr(0, 7);
  for (auto& ch : scheme) ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
  if (scheme != "bearer ") return {};
  const auto start = h.find_first_not_of(' ', 7);
  return start == std::string::npos ? std::string{} : h.substr(start);
}

bool is_probe(const std::string& path) { return path == "/v1/health" || path == "/v1/ready"; }

}  // namespace

App::App(const Config& config, Store& store, const FirebaseVerifier* verifier,
         RateLimiter::Clock clock, SpaceWeatherService* space_weather)
    : config_(config),
      store_(store),
      verifier_(verifier),
      space_weather_(space_weather),
      cors_(config.cors_origins),
      limiter_(config.rate_limit_per_minute, std::move(clock)) {
  server_.set_payload_max_length(kMaxBodyBytes);
  server_.set_read_timeout(10, 0);
  server_.set_write_timeout(10, 0);
  server_.set_keep_alive_max_count(100);

  server_.set_pre_routing_handler([this](const httplib::Request& req, httplib::Response& res) {
    t_started = std::chrono::steady_clock::now();
    const auto incoming = req.get_header_value("X-Request-Id");
    res.set_header("X-Request-Id", is_safe_request_id(incoming) ? incoming : new_request_id());
    for (const auto& [k, v] : security_headers(config_.environment)) res.set_header(k, v);

    const auto origin = req.has_header("Origin")
                            ? std::optional<std::string>(req.get_header_value("Origin"))
                            : std::nullopt;

    if (req.method == "OPTIONS") {
      const auto allowed =
          origin ? cors_.preflight(*origin, req.get_header_value("Access-Control-Request-Method"),
                                   req.get_header_value("Access-Control-Request-Headers"))
                 : std::nullopt;
      if (!allowed) {
        res.set_header("Vary", "Origin");
        send_error(res, 403, "cors_refused", "This origin, method or header is not allowed.");
        return httplib::Server::HandlerResponse::Handled;
      }
      for (const auto& [k, v] : *allowed) res.set_header(k, v);
      res.status = 204;
      return httplib::Server::HandlerResponse::Handled;
    }
    for (const auto& [k, v] : cors_.response_headers(origin)) res.set_header(k, v);

    if (!is_probe(req.path)) {
      const auto key = client_address(req.remote_addr, req.get_header_value("X-Forwarded-For"),
                                      config_.trusted_proxy_hops);
      const auto d = limiter_.check(key);
      if (!d.allowed) {
        res.set_header("Retry-After", std::to_string(d.retry_after_s));
        send_error(res, 429, "rate_limited", "Too many requests. Try again shortly.");
        return httplib::Server::HandlerResponse::Handled;
      }
    }
    return httplib::Server::HandlerResponse::Unhandled;
  });

  // Fills in a JSON body for errors raised by the server itself (no route,
  // body too large, and so on). Handlers' own errors already have one.
  server_.set_error_handler([](const httplib::Request&, httplib::Response& res) {
    if (!res.body.empty()) return;
    switch (res.status) {
      case 404:
        send_error(res, 404, "not_found", "No such endpoint.");
        break;
      case 413:
        send_error(res, 413, "payload_too_large", "The request body is too large.");
        break;
      case 400:
        send_error(res, 400, "bad_request", "The request could not be read.");
        break;
      default:
        send_error(res, res.status, "error", "The request failed.");
    }
  });

  server_.set_exception_handler(
      [](const httplib::Request& req, httplib::Response& res, std::exception_ptr ep) {
        std::string kind = "exception";
        try {
          if (ep) std::rethrow_exception(ep);
        } catch (const StoreUnavailable&) {
          send_error(res, 503, "database_unavailable",
                     "The database is unavailable. Try again shortly.");
          log::warn("database unavailable", {{"request_id", request_id(res)}, {"path", req.path}});
          return;
        } catch (const QueryError& e) {
          // The server's message may quote data; only the SQLSTATE is logged.
          kind = "sqlstate " + e.sqlstate;
        } catch (const std::exception& e) {
          kind = e.what();
        } catch (...) {
        }
        log::error("unhandled error", {{"request_id", request_id(res)}, {"path", req.path},
                                       {"kind", kind}});
        send_error(res, 500, "internal_error", "Something went wrong on the server.");
      });

  server_.set_logger([](const httplib::Request& req, const httplib::Response& res) {
    const auto ms =
        std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t_started)
            .count();
    // No addresses, query strings, headers or bodies: they can identify
    // people or carry tokens.
    log::info("request", {{"request_id", request_id(res)},
                          {"method", req.method},
                          {"path", req.path},
                          {"status", res.status},
                          {"duration_ms", static_cast<long long>(ms + 0.5)}});
  });

  routes();
}

void App::routes() {
  server_.Get("/v1/health", [](const httplib::Request&, httplib::Response& res) {
    send(res, 200, {{"status", "ok"}, {"version", RAKIA_API_VERSION}});
  });

  server_.Get("/v1/ready", [this](const httplib::Request&, httplib::Response& res) {
    int version = 0;
    try {
      version = store_.schema_version();
    } catch (const StoreUnavailable&) {
      send_error(res, 503, "database_unavailable", "The database is unavailable.");
      return;
    } catch (const QueryError& e) {
      // Most likely the schema is missing (migrations not applied).
      log::warn("readiness query failed", {{"sqlstate", e.sqlstate}});
      send_error(res, 503, "schema_unavailable",
                 "The database schema is missing or not readable by the API role.");
      return;
    }
    if (version != kExpectedSchemaVersion) {
      send_error(res, 503, "schema_mismatch",
                 "The database is at schema version " + std::to_string(version) +
                     "; this build of the API needs version " +
                     std::to_string(kExpectedSchemaVersion) + ".");
      return;
    }
    send(res, 200, {{"status", "ready"}, {"schema_version", version}});
  });

  server_.Get("/v1/metric-definitions", [this](const httplib::Request&, httplib::Response& res) {
    json items = json::array();
    for (const auto& m : store_.metric_definitions()) {
      items.push_back({{"code", m.code},
                       {"name", m.name},
                       {"unit", m.unit},
                       {"ucum", m.ucum},
                       {"plausible_min", m.plausible_min},
                       {"plausible_max", m.plausible_max}});
    }
    send(res, 200, {{"metric_definitions", items}});
  });

  // The live space-radiation environment (NOAA SWPC), with its source and
  // timestamps. Public: it is published open data, not personal data.
  server_.Get("/v1/space-weather", [this](const httplib::Request&, httplib::Response& res) {
    if (space_weather_ == nullptr) {
      send_error(res, 503, "space_weather_not_configured",
                 "Live space weather is not configured on this server.");
      return;
    }
    SpaceWeatherService::Result r;
    try {
      r = space_weather_->current();
    } catch (const SpaceWeatherError&) {
      send_error(res, 503, "space_weather_unavailable",
                 "Live space weather is unavailable right now. Try again shortly.");
      return;
    }
    const auto& d = r.data;
    json points = json::array();
    for (const auto& p : d.protons_10mev) points.push_back({{"time", p.time}, {"flux", p.flux}});
    const auto& latest = d.protons_10mev.back();
    // Open data that changes every few minutes: let clients and proxies keep
    // it briefly (this replaces the API-wide no-store).
    res.headers.erase("Cache-Control");
    res.set_header("Cache-Control", "public, max-age=60");
    send(res, 200,
         {{"source",
           {{"name", "NOAA Space Weather Prediction Center"},
            {"url", "https://www.swpc.noaa.gov/"},
            {"satellite", "GOES-" + std::to_string(d.satellite)},
            {"note", "Near-Earth environment at geostationary orbit, not a crew dose."}}},
          {"retrieved_at", iso8601_utc(d.retrieved_at)},
          {"stale", r.stale},
          {"proton_flux_10mev",
           {{"unit", "pfu"},
            {"s1_threshold", 10},
            {"latest", {{"time", latest.time}, {"flux", latest.flux}}},
            {"points", points}}},
          {"radiation_storm",
           {{"scale", "S" + std::to_string(d.s_level)},
            {"level", d.s_level},
            {"text", d.s_text},
            {"observed_at", d.scales_time}}},
          {"geomagnetic", {{"kp", d.kp}, {"observed_at", d.kp_time}}}});
  });

  // The signed-in user's account (created on first use) and their roles.
  server_.Get("/v1/me", [this](const httplib::Request& req, httplib::Response& res) {
    if (verifier_ == nullptr) {
      send_error(res, 503, "auth_not_configured",
                 "Sign-in is not configured on this server.");
      return;
    }
    const auto token = bearer_token(req);
    if (token.empty()) {
      res.set_header("WWW-Authenticate", "Bearer realm=\"rakia\"");
      send_error(res, 401, "unauthenticated", "Sign in to continue.");
      return;
    }
    VerifiedUser user;
    try {
      user = verifier_->verify(token);
    } catch (const AuthError& e) {
      // The reason is logged; the token and its claims never are.
      log::info("token refused", {{"request_id", request_id(res)}, {"reason", e.reason}});
      res.set_header("WWW-Authenticate", "Bearer realm=\"rakia\", error=\"invalid_token\"");
      send_error(res, 401, "invalid_token",
                 e.reason == "keys_unavailable"
                     ? "Sign-in cannot be checked right now. Try again shortly."
                     : "Your sign-in has expired or is not valid. Sign in again.");
      return;
    }
    const auto a = store_.account(user.uid);
    json memberships = json::array();
    for (const auto& m : a.memberships) {
      memberships.push_back({{"mission_id", m.mission_id},
                             {"mission_name", m.mission_name},
                             {"is_simulation", m.is_simulation},
                             {"role", m.role}});
    }
    send(res, 200,
         {{"user",
           {{"id", a.id},
            {"firebase_uid", a.firebase_uid},
            {"display_name", a.display_name ? json(*a.display_name) : json(nullptr)},
            {"created_at", a.created_at}}},
          {"memberships", memberships}});
  });
}

}  // namespace rakia
