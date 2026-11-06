// SPDX-License-Identifier: Apache-2.0
// The HTTP layer end to end over a real socket, with a fake store: routes,
// readiness, JSON errors, security and CORS headers, rate limiting, request
// ids and the body size limit.
#include <atomic>
#include <chrono>
#include <nlohmann/json.hpp>
#include <thread>

#include "app.hpp"
#include "log.hpp"
#include "rk_test.hpp"

using namespace std::chrono_literals;
using json = nlohmann::json;

namespace {

struct FakeStore final : rakia::Store {
  enum class Mode { ok, down, wrong_version, query_error };
  std::atomic<Mode> mode{Mode::ok};

  int schema_version() override {
    switch (mode.load()) {
      case Mode::down:
        throw rakia::StoreUnavailable("down");
      case Mode::query_error:
        throw rakia::QueryError("42P01", "relation does not exist: secret detail");
      case Mode::wrong_version:
        return rakia::kExpectedSchemaVersion - 1;
      case Mode::ok:
        break;
    }
    return rakia::kExpectedSchemaVersion;
  }
  std::vector<rakia::MetricDefinition> metric_definitions() override {
    if (mode == Mode::down) throw rakia::StoreUnavailable("down");
    if (mode == Mode::query_error) throw rakia::QueryError("XX000", "secret detail");
    return {{"heart_rate.resting", "Resting heart rate", "bpm", "/min", 30, 120}};
  }
};

rakia::Config config(std::uint32_t rate = 1000) {
  rakia::Config c;
  c.cors_origins = {"https://app.example"};
  c.rate_limit_per_minute = rate;
  c.db_host = "unused";
  c.db_name = "unused";
  c.db_user = "rakia_api";
  c.db_password = "unused";
  return c;
}

/// Serves [app] on an ephemeral localhost port for the life of the object.
class Running {
 public:
  explicit Running(rakia::App& app) : app_(app) {
    port_ = app_.server().bind_to_any_port("127.0.0.1");
    thread_ = std::thread([this] { app_.server().listen_after_bind(); });
    app_.server().wait_until_ready();
  }
  ~Running() {
    app_.server().stop();
    thread_.join();
  }
  httplib::Client client() const {
    httplib::Client c("127.0.0.1", port_);
    c.set_connection_timeout(5s);
    c.set_read_timeout(5s);
    return c;
  }

 private:
  rakia::App& app_;
  int port_ = 0;
  std::thread thread_;
};

json body(const httplib::Result& r) { return json::parse(r->body); }

}  // namespace

TEST("health answers without touching the database") {
  FakeStore store;
  store.mode = FakeStore::Mode::down;
  rakia::App app(config(), store);
  Running run(app);
  const auto r = run.client().Get("/v1/health");
  CHECK(r);
  CHECK_EQ(r->status, 200);
  CHECK_EQ(body(r)["status"], "ok");
  CHECK_EQ(r->get_header_value("Content-Type"), std::string("application/json; charset=utf-8"));
}

TEST("ready reflects the database and its schema version") {
  FakeStore store;
  rakia::App app(config(), store);
  Running run(app);
  auto c = run.client();
  auto r = c.Get("/v1/ready");
  CHECK_EQ(r->status, 200);
  CHECK_EQ(body(r)["schema_version"], rakia::kExpectedSchemaVersion);

  store.mode = FakeStore::Mode::down;
  r = c.Get("/v1/ready");
  CHECK_EQ(r->status, 503);
  CHECK_EQ(body(r)["error"]["code"], "database_unavailable");

  store.mode = FakeStore::Mode::wrong_version;
  r = c.Get("/v1/ready");
  CHECK_EQ(r->status, 503);
  CHECK_EQ(body(r)["error"]["code"], "schema_mismatch");

  store.mode = FakeStore::Mode::query_error;
  r = c.Get("/v1/ready");
  CHECK_EQ(r->status, 503);
  CHECK_EQ(body(r)["error"]["code"], "schema_unavailable");
  CHECK(r->body.find("secret detail") == std::string::npos);
}

TEST("metric definitions come from the store") {
  FakeStore store;
  rakia::App app(config(), store);
  Running run(app);
  const auto r = run.client().Get("/v1/metric-definitions");
  CHECK_EQ(r->status, 200);
  const auto items = body(r)["metric_definitions"];
  CHECK_EQ(items.size(), std::size_t{1});
  CHECK_EQ(items[0]["code"], "heart_rate.resting");
  CHECK_EQ(items[0]["ucum"], "/min");
}

TEST("database failures become 503 or 500 without leaking server messages") {
  FakeStore store;
  rakia::App app(config(), store);
  Running run(app);
  auto c = run.client();
  store.mode = FakeStore::Mode::down;
  auto r = c.Get("/v1/metric-definitions");
  CHECK_EQ(r->status, 503);
  CHECK_EQ(body(r)["error"]["code"], "database_unavailable");
  store.mode = FakeStore::Mode::query_error;
  r = c.Get("/v1/metric-definitions");
  CHECK_EQ(r->status, 500);
  CHECK_EQ(body(r)["error"]["code"], "internal_error");
  CHECK(r->body.find("secret detail") == std::string::npos);
}

TEST("unknown endpoints get a JSON 404 with the request id") {
  FakeStore store;
  rakia::App app(config(), store);
  Running run(app);
  const auto r = run.client().Get("/v1/nothing-here");
  CHECK_EQ(r->status, 404);
  const auto b = body(r);
  CHECK_EQ(b["error"]["code"], "not_found");
  CHECK_EQ(b["error"]["request_id"].get<std::string>(), r->get_header_value("X-Request-Id"));
}

TEST("every response carries the security headers") {
  FakeStore store;
  rakia::App app(config(), store);
  Running run(app);
  auto c = run.client();
  for (const char* path : {"/v1/health", "/v1/nothing-here"}) {
    const auto r = c.Get(path);
    CHECK_EQ(r->get_header_value("X-Content-Type-Options"), std::string("nosniff"));
    CHECK_EQ(r->get_header_value("Cache-Control"), std::string("no-store"));
    CHECK_EQ(r->get_header_value("X-Frame-Options"), std::string("DENY"));
    CHECK(!r->get_header_value("Content-Security-Policy").empty());
    CHECK_EQ(r->get_header_value("X-Request-Id").size(), std::size_t{32});
  }
}

TEST("a safe request id from the caller is kept; an unsafe one is replaced") {
  FakeStore store;
  rakia::App app(config(), store);
  Running run(app);
  auto c = run.client();
  auto r = c.Get("/v1/health", httplib::Headers{{"X-Request-Id", "trace-0123456789"}});
  CHECK_EQ(r->get_header_value("X-Request-Id"), std::string("trace-0123456789"));
  r = c.Get("/v1/health", httplib::Headers{{"X-Request-Id", "bad id!"}});
  CHECK(r->get_header_value("X-Request-Id") != "bad id!");
  CHECK_EQ(r->get_header_value("X-Request-Id").size(), std::size_t{32});
}

TEST("CORS: allowed origins are echoed, others are not") {
  FakeStore store;
  rakia::App app(config(), store);
  Running run(app);
  auto c = run.client();
  auto r = c.Get("/v1/health", httplib::Headers{{"Origin", "https://app.example"}});
  CHECK_EQ(r->get_header_value("Access-Control-Allow-Origin"), std::string("https://app.example"));
  r = c.Get("/v1/health", httplib::Headers{{"Origin", "https://evil.example"}});
  CHECK(!r->has_header("Access-Control-Allow-Origin"));
  CHECK_EQ(r->get_header_value("Vary"), std::string("Origin"));
}

TEST("CORS preflight: 204 when allowed, 403 otherwise") {
  FakeStore store;
  rakia::App app(config(), store);
  Running run(app);
  auto c = run.client();
  auto r = c.Options("/v1/metric-definitions", httplib::Headers{{"Origin", "https://app.example"},
                                                {"Access-Control-Request-Method", "GET"},
                                                {"Access-Control-Request-Headers", "authorization"}});
  CHECK_EQ(r->status, 204);
  CHECK_EQ(r->get_header_value("Access-Control-Allow-Origin"), std::string("https://app.example"));
  r = c.Options("/v1/metric-definitions",
                httplib::Headers{{"Origin", "https://evil.example"}, {"Access-Control-Request-Method", "GET"}});
  CHECK_EQ(r->status, 403);
  CHECK(!r->has_header("Access-Control-Allow-Origin"));
}

TEST("rate limiting returns 429 with Retry-After, and spares the probes") {
  FakeStore store;
  rakia::App app(config(3), store);
  Running run(app);
  auto c = run.client();
  for (int i = 0; i < 3; ++i) CHECK_EQ(c.Get("/v1/metric-definitions")->status, 200);
  const auto r = c.Get("/v1/metric-definitions");
  CHECK_EQ(r->status, 429);
  CHECK_EQ(body(r)["error"]["code"], "rate_limited");
  CHECK(!r->get_header_value("Retry-After").empty());
  CHECK_EQ(c.Get("/v1/health")->status, 200);
  CHECK_EQ(c.Get("/v1/ready")->status, 200);
}

TEST("bodies over the limit are refused") {
  FakeStore store;
  rakia::App app(config(), store);
  // No endpoint takes a body yet; a test-only one shows the limit applies
  // before a handler runs.
  bool reached = false;
  app.server().Post("/test/body", [&](const httplib::Request&, httplib::Response& res) {
    reached = true;
    res.status = 204;
  });
  Running run(app);
  auto c = run.client();
  CHECK_EQ(c.Post("/test/body", std::string(1024, 'x'), "application/json")->status, 204);
  CHECK(reached);
  reached = false;
  const auto r = c.Post("/test/body", std::string(rakia::kMaxBodyBytes + 1, 'x'),
                        "application/json");
  CHECK(r);
  CHECK_EQ(r->status, 413);
  CHECK(!reached);
}

int main() {
  rakia::log::set_enabled(false);
  return rk::run("http");
}
