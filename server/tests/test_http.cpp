// SPDX-License-Identifier: Apache-2.0
// The HTTP layer end to end over a real socket, with a fake store: routes,
// readiness, JSON errors, security and CORS headers, rate limiting, request
// ids and the body size limit.
#include <atomic>
#include <chrono>
#include <nlohmann/json.hpp>
#include <set>
#include <thread>

#include "app.hpp"
#include "log.hpp"
#include "rk_test.hpp"
#include "sync_fixture.hpp"
#include "token_fixture.hpp"

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
  std::vector<std::string> account_calls;
  std::set<std::string> existing;
  std::vector<std::string> created;
  std::set<std::string> seen_tokens;
  static rakia::Account sample(const std::string& firebase_uid) {
    rakia::Account a;
    a.id = "0190b8f4-0000-7000-8000-000000000001";
    a.firebase_uid = firebase_uid;
    a.created_at = "2026-11-08T09:00:00Z";
    a.memberships.push_back({"0190b8f4-0000-7000-8000-0000000000aa", "Analog mission", false,
                             "astronaut"});
    return a;
  }
  std::optional<rakia::Account> find_account(const std::string& firebase_uid) override {
    if (mode == Mode::down) throw rakia::StoreUnavailable("down");
    account_calls.push_back(firebase_uid);
    if (existing.count(firebase_uid) == 0) return std::nullopt;
    return sample(firebase_uid);
  }
  rakia::Account create_account(const std::string& firebase_uid) override {
    created.push_back(firebase_uid);
    existing.insert(firebase_uid);
    return sample(firebase_uid);
  }
  bool remember_turnstile_token(const std::string& hash) override {
    return seen_tokens.insert(hash).second;
  }
  std::vector<rakia::SyncBatch> batches;
  std::optional<rakia::SyncError> sync_error;
  rakia::SyncResult sync_batch(const std::string& firebase_uid,
                               const rakia::SyncBatch& batch) override {
    account_calls.push_back(firebase_uid);
    if (sync_error) throw *sync_error;
    batches.push_back(batch);
    return {batch.records.back().client_seq, static_cast<int>(batch.records.size()), false};
  }
};

/// Cloudflare's answers, scripted.
struct FakeSiteverify final : rakia::SiteverifyClient {
  bool down = false;
  rakia::SiteverifyResult answer;
  std::vector<std::string> secrets_seen;
  rakia::SiteverifyResult verify(const std::string& secret, const std::string&,
                                 const std::string&) override {
    if (down) throw std::runtime_error("unreachable");
    secrets_seen.push_back(secret);
    return answer;
  }
};

/// A verifier over a freshly generated key, with the clock at rk::kNow.
struct TestAuth {
  rk::SigningKey key;
  rakia::StaticKeys keys;
  rakia::FirebaseVerifier verifier;
  TestAuth() : verifier(rk::kProject, keys, [] { return rk::kNow; }) {
    keys.add("key-1", rakia::key_from_certificate_pem(key.certificate_pem));
  }
  std::string token(const std::string& uid) const {
    return key.sign(rk::header(), rk::valid_claims(uid));
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

TEST("/v1/me answers 503 when sign-in is not configured") {
  FakeStore store;
  rakia::App app(config(), store);
  Running run(app);
  const auto r = run.client().Get("/v1/me");
  CHECK_EQ(r->status, 503);
  CHECK_EQ(body(r)["error"]["code"], "auth_not_configured");
}

TEST("/v1/me needs a bearer token and challenges without one") {
  FakeStore store;
  TestAuth auth;
  rakia::App app(config(), store, &auth.verifier);
  Running run(app);
  auto c = run.client();
  auto r = c.Get("/v1/me");
  CHECK_EQ(r->status, 401);
  CHECK_EQ(body(r)["error"]["code"], "unauthenticated");
  CHECK_EQ(r->get_header_value("WWW-Authenticate"), std::string("Bearer realm=\"rakia\""));
  r = c.Get("/v1/me", httplib::Headers{{"Authorization", "Basic dXNlcjpwYXNz"}});
  CHECK_EQ(r->status, 401);
  CHECK(store.account_calls.empty());
}

TEST("/v1/me refuses an invalid token without reaching the database") {
  FakeStore store;
  TestAuth auth;
  rakia::App app(config(), store, &auth.verifier);
  Running run(app);
  const rk::SigningKey stranger;
  const auto r = run.client().Get(
      "/v1/me", httplib::Headers{{"Authorization",
                                  "Bearer " + stranger.sign(rk::header(), rk::valid_claims())}});
  CHECK_EQ(r->status, 401);
  CHECK_EQ(body(r)["error"]["code"], "invalid_token");
  CHECK(r->get_header_value("WWW-Authenticate").find("invalid_token") != std::string::npos);
  CHECK(store.account_calls.empty());
}

TEST("/v1/me returns the verified user's account and roles") {
  FakeStore store;
  store.existing.insert("astronaut-7");
  TestAuth auth;
  rakia::App app(config(), store, &auth.verifier);
  Running run(app);
  const auto r = run.client().Get(
      "/v1/me", httplib::Headers{{"Authorization", "bearer " + auth.token("astronaut-7")}});
  CHECK_EQ(r->status, 200);
  const auto b = body(r);
  CHECK_EQ(b["user"]["firebase_uid"], "astronaut-7");
  CHECK(b["user"]["display_name"].is_null());
  CHECK_EQ(b["memberships"][0]["role"], "astronaut");
  CHECK_EQ(store.account_calls.size(), std::size_t{1});
  CHECK_EQ(store.account_calls[0], std::string("astronaut-7"));
}

TEST("GET /v1/me never creates an account") {
  FakeStore store;
  TestAuth auth;
  rakia::App app(config(), store, &auth.verifier);
  Running run(app);
  const auto r = run.client().Get(
      "/v1/me", httplib::Headers{{"Authorization", "Bearer " + auth.token("newcomer")}});
  CHECK_EQ(r->status, 404);
  CHECK_EQ(body(r)["error"]["code"], "no_account");
  CHECK(store.created.empty());
}

namespace {
rakia::Config with_turnstile(rakia::Environment env = rakia::Environment::staging) {
  auto c = config();
  c.environment = env;
  c.turnstile_secret = "0x4AAAAAAAtest-secret";
  c.turnstile_hostnames = {"app.example"};
  return c;
}
rakia::SiteverifyResult pass(const std::string& host = "app.example",
                             const std::string& action = "create-account") {
  rakia::SiteverifyResult r;
  r.success = true;
  r.hostname = host;
  r.action = action;
  return r;
}
}  // namespace

TEST("POST /v1/me creates an account only after Turnstile passes, once per token") {
  FakeStore store;
  TestAuth auth;
  FakeSiteverify cf;
  const auto cfg = with_turnstile();
  rakia::TurnstileGuard guard(cfg, cf);
  rakia::App app(cfg, store, &auth.verifier, {}, nullptr, &guard);
  Running run(app);
  auto c = run.client();
  const httplib::Headers bearer{{"Authorization", "Bearer " + auth.token("newcomer")}};

  // No token: refused, nothing created.
  auto r = c.Post("/v1/me", bearer, "", "application/json");
  CHECK_EQ(r->status, 403);
  CHECK_EQ(body(r)["error"]["code"], "turnstile_failed");
  CHECK(store.created.empty());

  // Cloudflare says no.
  auto h = bearer;
  h.emplace("X-Turnstile-Token", "token-1");
  cf.answer.success = false;
  r = c.Post("/v1/me", h, "", "application/json");
  CHECK_EQ(r->status, 403);
  CHECK(store.created.empty());

  // Solved on another site, or for another action.
  cf.answer = pass("evil.example");
  r = c.Post("/v1/me", h, "", "application/json");
  CHECK_EQ(r->status, 403);
  cf.answer = pass("app.example", "login");
  r = c.Post("/v1/me", h, "", "application/json");
  CHECK_EQ(r->status, 403);
  CHECK(store.created.empty());

  // Valid: created; the secret goes to Cloudflare only.
  cf.answer = pass();
  r = c.Post("/v1/me", h, "", "application/json");
  CHECK_EQ(r->status, 201);
  CHECK_EQ(body(r)["user"]["firebase_uid"], "newcomer");
  CHECK_EQ(store.created.size(), std::size_t{1});
  CHECK_EQ(cf.secrets_seen.back(), std::string("0x4AAAAAAAtest-secret"));
  CHECK(r->body.find("test-secret") == std::string::npos);

  // The account exists now: POST returns it without another check.
  const auto checks = cf.secrets_seen.size();
  r = c.Post("/v1/me", bearer, "", "application/json");
  CHECK_EQ(r->status, 200);
  CHECK_EQ(cf.secrets_seen.size(), checks);

  // The same token cannot create a second account.
  httplib::Headers other{{"Authorization", "Bearer " + auth.token("second")},
                         {"X-Turnstile-Token", "token-1"}};
  r = c.Post("/v1/me", other, "", "application/json");
  CHECK_EQ(r->status, 403);
  CHECK_EQ(store.created.size(), std::size_t{1});
}

TEST("POST /v1/me: testing keys, outages and missing configuration fail closed") {
  FakeStore store;
  TestAuth auth;
  FakeSiteverify cf;
  const auto cfg = with_turnstile();
  rakia::TurnstileGuard guard(cfg, cf);
  rakia::App app(cfg, store, &auth.verifier, {}, nullptr, &guard);
  Running run(app);
  auto c = run.client();
  httplib::Headers h{{"Authorization", "Bearer " + auth.token("newcomer")},
                     {"X-Turnstile-Token", "token-2"}};

  cf.answer = pass("example.com", "");
  cf.answer.testing_key = true;
  auto r = c.Post("/v1/me", h, "", "application/json");
  CHECK_EQ(r->status, 403);

  cf.down = true;
  r = c.Post("/v1/me", h, "", "application/json");
  CHECK_EQ(r->status, 503);
  CHECK_EQ(body(r)["error"]["code"], "turnstile_unavailable");
  CHECK(store.created.empty());

  // Staging without a Turnstile secret refuses to create accounts.
  FakeStore store2;
  auto staging = config();
  staging.environment = rakia::Environment::staging;
  rakia::App app2(staging, store2, &auth.verifier);
  Running run2(app2);
  r = run2.client().Post(
      "/v1/me", httplib::Headers{{"Authorization", "Bearer " + auth.token("newcomer")}}, "",
      "application/json");
  CHECK_EQ(r->status, 503);
  CHECK_EQ(body(r)["error"]["code"], "account_creation_not_configured");
  CHECK(store2.created.empty());
}

TEST("POST /v1/me in development: unchecked without Turnstile; testing keys accepted") {
  FakeStore store;
  TestAuth auth;
  rakia::App app(config(), store, &auth.verifier);
  Running run(app);
  const auto r = run.client().Post(
      "/v1/me", httplib::Headers{{"Authorization", "Bearer " + auth.token("dev-user")}}, "",
      "application/json");
  CHECK_EQ(r->status, 201);

  FakeStore store2;
  FakeSiteverify cf;
  cf.answer = pass("example.com", "");
  cf.answer.testing_key = true;
  const auto cfg = with_turnstile(rakia::Environment::development);
  rakia::TurnstileGuard guard(cfg, cf);
  rakia::App app2(cfg, store2, &auth.verifier, {}, nullptr, &guard);
  Running run2(app2);
  const auto r2 = run2.client().Post(
      "/v1/me",
      httplib::Headers{{"Authorization", "Bearer " + auth.token("dev-user")},
                       {"X-Turnstile-Token", "XXXX.DUMMY.TOKEN.XXXX"}},
      "", "application/json");
  CHECK_EQ(r2->status, 201);
}

TEST("POST /v1/sync/batches: sign-in required; hashes verified before the store is reached") {
  FakeStore store;
  TestAuth auth;
  rakia::App app(config(), store, &auth.verifier);
  Running run(app);
  auto c = run.client();
  rk::Device d;
  const auto good = d.batch(json::array({d.record("heart_rate.resting", 58.0, "/min"),
                                         d.record("heart_rate.resting", 59.0, "/min")}));

  auto r = c.Post("/v1/sync/batches", good.dump(), "application/json");
  CHECK_EQ(r->status, 401);

  const httplib::Headers bearer{{"Authorization", "Bearer " + auth.token("astronaut-7")}};
  r = c.Post("/v1/sync/batches", bearer, "{not json", "application/json");
  CHECK_EQ(r->status, 400);
  CHECK_EQ(body(r)["error"]["code"], "invalid_json");

  auto tampered = good;
  tampered["records"][1]["value"] = 95.0;
  r = c.Post("/v1/sync/batches", bearer, tampered.dump(), "application/json");
  CHECK_EQ(r->status, 400);
  CHECK_EQ(body(r)["error"]["code"], "hash_mismatch");
  // The refusal does not echo health values.
  CHECK(r->body.find("95") == std::string::npos);
  CHECK(store.batches.empty());

  r = c.Post("/v1/sync/batches", bearer, good.dump(), "application/json");
  CHECK_EQ(r->status, 200);
  CHECK_EQ(body(r)["acked_through_seq"], 2);
  CHECK_EQ(body(r)["accepted"], 2);
  CHECK_EQ(body(r)["duplicate"], false);
  CHECK_EQ(store.batches.size(), std::size_t{1});
  CHECK_EQ(store.batches[0].records[1].value, 59.0);
  CHECK_EQ(store.account_calls.back(), std::string("astronaut-7"));

  // What the store refuses reaches the client with its code and status.
  store.sync_error = rakia::SyncError(409, "chain_gap", "The batch does not continue.");
  r = c.Post("/v1/sync/batches", bearer, good.dump(), "application/json");
  CHECK_EQ(r->status, 409);
  CHECK_EQ(body(r)["error"]["code"], "chain_gap");
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
