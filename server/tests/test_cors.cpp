// SPDX-License-Identifier: Apache-2.0
// CORS: exact allow-list, preflight limits, and Vary on every answer.
#include "cors.hpp"
#include "rk_test.hpp"
#include "security.hpp"

using rakia::Cors;

namespace {
std::string header(const std::vector<std::pair<std::string, std::string>>& h,
                   const std::string& name) {
  for (const auto& [k, v] : h) {
    if (k == name) return v;
  }
  return {};
}
const Cors cors({"https://app.example", "http://localhost:5000"});
}  // namespace

TEST("only listed origins are allowed, compared exactly") {
  CHECK(cors.allows("https://app.example"));
  CHECK(!cors.allows("https://app.example.evil"));
  CHECK(!cors.allows("https://evil.app.example"));
  CHECK(!cors.allows("http://app.example"));
  CHECK(!cors.allows("https://APP.example"));
  CHECK(!cors.allows("null"));
}

TEST("responses echo an allowed origin and always vary on Origin") {
  const auto ok = cors.response_headers(std::string("https://app.example"));
  CHECK_EQ(header(ok, "Access-Control-Allow-Origin"), std::string("https://app.example"));
  CHECK_EQ(header(ok, "Vary"), std::string("Origin"));
  const auto no = cors.response_headers(std::string("https://evil.example"));
  CHECK(header(no, "Access-Control-Allow-Origin").empty());
  CHECK_EQ(header(no, "Vary"), std::string("Origin"));
  CHECK(header(cors.response_headers(std::nullopt), "Access-Control-Allow-Origin").empty());
}

TEST("never a wildcard, never credentials") {
  const auto ok = cors.response_headers(std::string("https://app.example"));
  CHECK(header(ok, "Access-Control-Allow-Credentials").empty());
  for (const auto& [k, v] : ok) CHECK(v != "*");
}

TEST("preflight: allowed origin, method and headers") {
  const auto p = cors.preflight("https://app.example", "POST", "content-type, Authorization");
  CHECK(p.has_value());
  CHECK_EQ(header(*p, "Access-Control-Allow-Methods"), std::string("GET, POST"));
  CHECK_EQ(header(*p, "Access-Control-Max-Age"), std::string("600"));
}

TEST("preflight refuses other origins, methods and headers") {
  CHECK(!cors.preflight("https://evil.example", "GET", "").has_value());
  CHECK(!cors.preflight("https://app.example", "DELETE", "").has_value());
  CHECK(!cors.preflight("https://app.example", "PUT", "").has_value());
  CHECK(!cors.preflight("https://app.example", "GET", "X-Custom").has_value());
}

TEST("request ids: generated ones are 32 hex characters and differ") {
  const auto a = rakia::new_request_id();
  const auto b = rakia::new_request_id();
  CHECK_EQ(a.size(), std::size_t{32});
  CHECK(a != b);
  CHECK(rakia::is_safe_request_id(a));
}

TEST("request ids from callers are accepted only when safe to log") {
  CHECK(rakia::is_safe_request_id("abcd-1234-EFGH"));
  CHECK(!rakia::is_safe_request_id("short"));
  CHECK(!rakia::is_safe_request_id("has space in it"));
  CHECK(!rakia::is_safe_request_id("line\nbreak-injection"));
  CHECK(!rakia::is_safe_request_id(std::string(65, 'a')));
}

TEST("security headers: HSTS only where TLS terminates in front") {
  const auto dev = rakia::security_headers(rakia::Environment::development);
  const auto prod = rakia::security_headers(rakia::Environment::production);
  CHECK(header(dev, "Strict-Transport-Security").empty());
  CHECK(!header(prod, "Strict-Transport-Security").empty());
  CHECK_EQ(header(prod, "Cache-Control"), std::string("no-store"));
  CHECK_EQ(header(prod, "X-Content-Type-Options"), std::string("nosniff"));
  CHECK(header(prod, "Content-Security-Policy").find("default-src 'none'") != std::string::npos);
}

RK_MAIN("cors")
