// SPDX-License-Identifier: Apache-2.0
// Turnstile: parsing Cloudflare's siteverify answers, the token hash kept
// against replays, RAKIA's rules for accepting a token, and (with
// RAKIA_API_NETWORK_TESTS=1) a real siteverify call with Cloudflare's
// published testing secrets, which always pass or always fail.
#include <cstdlib>
#include <set>
#include <stdexcept>

#include "log.hpp"
#include "rk_test.hpp"
#include "turnstile.hpp"

namespace {

struct Scripted final : rakia::SiteverifyClient {
  bool down = false;
  rakia::SiteverifyResult answer;
  rakia::SiteverifyResult verify(const std::string&, const std::string&,
                                 const std::string&) override {
    if (down) throw std::runtime_error("unreachable");
    return answer;
  }
};

rakia::Config config(rakia::Environment env) {
  rakia::Config c;
  c.environment = env;
  c.turnstile_secret = "0x4AAAAAAAsecret";
  c.turnstile_hostnames = {"staging.rakia-app.pages.dev"};
  return c;
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

TEST("siteverify answers parse, including Cloudflare's testing-key marker") {
  const auto ok = rakia::parse_siteverify(
      R"({"success":true,"error-codes":[],"challenge_ts":"2026-11-09T16:31:46.660Z",)"
      R"("hostname":"staging.rakia-app.pages.dev","action":"create-account"})");
  CHECK(ok.success);
  CHECK_EQ(ok.hostname, std::string("staging.rakia-app.pages.dev"));
  CHECK_EQ(ok.action, std::string("create-account"));
  CHECK(!ok.testing_key);

  const auto testing = rakia::parse_siteverify(
      R"({"success":true,"hostname":"example.com","metadata":{"result_with_testing_key":true}})");
  CHECK(testing.testing_key);

  const auto no = rakia::parse_siteverify(
      R"({"success":false,"error-codes":["timeout-or-duplicate"]})");
  CHECK(!no.success);
  CHECK_EQ(no.error_codes.at(0), std::string("timeout-or-duplicate"));

  CHECK_THROWS(std::runtime_error, rakia::parse_siteverify("<html>"));
  CHECK_THROWS(std::runtime_error, rakia::parse_siteverify(R"({"hostname":"x"})"));
  CHECK_THROWS(std::runtime_error, rakia::parse_siteverify(R"({"success":"yes"})"));
}

TEST("token hashes are SHA-256, hex") {
  CHECK_EQ(rakia::token_hash_hex("abc"),
           std::string("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"));
  CHECK(rakia::token_hash_hex("a") != rakia::token_hash_hex("b"));
}

TEST("the guard: success, hostname, action, testing keys, outages and replays") {
  Scripted cf;
  std::set<std::string> seen;
  const auto remember = [&](const std::string& h) { return seen.insert(h).second; };
  const auto staging = config(rakia::Environment::staging);
  const rakia::TurnstileGuard guard(staging, cf);

  CHECK_EQ(guard.check("", "", remember).reason, std::string("missing"));
  CHECK_EQ(guard.check(std::string(2049, 'x'), "", remember).reason, std::string("too_long"));

  cf.answer.success = false;
  CHECK_EQ(guard.check("t1", "", remember).reason, std::string("rejected"));

  cf.answer = {true, {}, "evil.example", "create-account", false};
  CHECK_EQ(guard.check("t1", "", remember).reason, std::string("wrong_hostname"));
  cf.answer = {true, {}, "staging.rakia-app.pages.dev", "login", false};
  CHECK_EQ(guard.check("t1", "", remember).reason, std::string("wrong_action"));
  cf.answer = {true, {}, "example.com", "", true};
  CHECK_EQ(guard.check("t1", "", remember).reason, std::string("testing_key"));
  cf.down = true;
  CHECK_EQ(guard.check("t1", "", remember).reason, std::string("unavailable"));
  CHECK(seen.empty());  // nothing is remembered until a token passes

  cf.down = false;
  cf.answer = {true, {}, "staging.rakia-app.pages.dev", "create-account", false};
  CHECK(guard.check("t1", "", remember).allowed);
  CHECK_EQ(guard.check("t1", "", remember).reason, std::string("replayed"));

  // Development accepts Cloudflare's testing keys (hostname example.com).
  const auto dev = config(rakia::Environment::development);
  const rakia::TurnstileGuard dev_guard(dev, cf);
  cf.answer = {true, {}, "example.com", "", true};
  CHECK(dev_guard.check("t2", "", remember).allowed);
}

TEST("siteverify with Cloudflare's testing secrets (network; RAKIA_API_NETWORK_TESTS=1)") {
  if (!network_tests()) return;
  rakia::CloudflareSiteverify cf;
  const auto pass =
      cf.verify("1x0000000000000000000000000000000AA", "XXXX.DUMMY.TOKEN.XXXX", "");
  CHECK(pass.success);
  CHECK(pass.testing_key);
  const auto fail =
      cf.verify("2x0000000000000000000000000000000AA", "XXXX.DUMMY.TOKEN.XXXX", "");
  CHECK(!fail.success);
}

int main() {
  rakia::log::set_enabled(false);
  return rk::run("turnstile");
}
