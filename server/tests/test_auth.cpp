// SPDX-License-Identifier: Apache-2.0
// Firebase ID-token verification: a valid token passes; every way a token
// can be wrong is refused with a reason that is safe to log.
#include <cstdlib>

#include "firebase_auth.hpp"
#include "log.hpp"
#include "rk_test.hpp"
#include "token_fixture.hpp"

using rakia::AuthError;
using rakia::FirebaseVerifier;
using rakia::StaticKeys;

namespace {

const rk::SigningKey& signing_key() {
  static const rk::SigningKey k;
  return k;
}

StaticKeys& keys() {
  static StaticKeys k = [] {
    StaticKeys s;
    s.add("key-1", rakia::key_from_certificate_pem(signing_key().certificate_pem));
    return s;
  }();
  return k;
}

FirebaseVerifier verifier(std::int64_t now = rk::kNow) {
  return FirebaseVerifier(rk::kProject, keys(), [now] { return now; });
}

std::string refusal(const std::string& token, std::int64_t now = rk::kNow) {
  try {
    verifier(now).verify(token);
  } catch (const AuthError& e) {
    return e.reason;
  }
  return "accepted";
}

std::string token(const nlohmann::json& claims, const nlohmann::json& hdr = rk::header()) {
  return signing_key().sign(hdr, claims);
}

nlohmann::json with(nlohmann::json j, const std::string& key, nlohmann::json value) {
  j[key] = std::move(value);
  return j;
}

nlohmann::json without(nlohmann::json j, const std::string& key) {
  j.erase(key);
  return j;
}

}  // namespace

TEST("a valid token yields the user") {
  const auto user = verifier().verify(token(rk::valid_claims("astronaut-7")));
  CHECK_EQ(user.uid, std::string("astronaut-7"));
  CHECK_EQ(user.expires_at, rk::kNow + 3540);
  CHECK_EQ(user.auth_time, rk::kNow - 600);
}

TEST("time: expired, issued in the future, signed in in the future") {
  const auto claims = rk::valid_claims();
  CHECK_EQ(refusal(token(claims), rk::kNow + 3540 + 61), std::string("expired"));
  // Within the leeway the token is still accepted.
  CHECK_EQ(refusal(token(claims), rk::kNow + 3540 + 30), std::string("accepted"));
  CHECK_EQ(refusal(token(with(claims, "iat", rk::kNow + 120))), std::string("issued_in_future"));
  CHECK_EQ(refusal(token(with(claims, "auth_time", rk::kNow + 120))),
           std::string("auth_time_in_future"));
}

TEST("audience and issuer must name this project") {
  const auto claims = rk::valid_claims();
  CHECK_EQ(refusal(token(with(claims, "aud", "another-project"))), std::string("wrong_audience"));
  CHECK_EQ(refusal(token(with(claims, "iss", "https://securetoken.google.com/another-project"))),
           std::string("wrong_issuer"));
  CHECK_EQ(refusal(token(with(claims, "iss", "https://accounts.google.com"))),
           std::string("wrong_issuer"));
}

TEST("the subject must be a non-empty string of at most 128 characters") {
  const auto claims = rk::valid_claims();
  CHECK_EQ(refusal(token(with(claims, "sub", ""))), std::string("bad_subject"));
  CHECK_EQ(refusal(token(with(claims, "sub", std::string(129, 'a')))),
           std::string("bad_subject"));
  CHECK_EQ(refusal(token(with(claims, "sub", std::string("a\nb")))), std::string("bad_subject"));
  CHECK_EQ(refusal(token(with(claims, "sub", 42))), std::string("missing_sub"));
  CHECK_EQ(refusal(token(with(claims, "sub", std::string(128, 'a')))), std::string("accepted"));
}

TEST("required claims must be present and of the right type") {
  for (const char* claim : {"exp", "iat", "auth_time", "aud", "iss", "sub"}) {
    CHECK_EQ(refusal(token(without(rk::valid_claims(), claim))),
             std::string("missing_") + claim);
  }
  CHECK_EQ(refusal(token(with(rk::valid_claims(), "exp", "soon"))), std::string("missing_exp"));
}

TEST("only RS256 is accepted: never none, never HMAC") {
  const auto claims = rk::valid_claims();
  // "none": no signature at all.
  const auto none = rk::b64url(nlohmann::json{{"alg", "none"}, {"kid", "key-1"}}.dump()) + "." +
                    rk::b64url(claims.dump()) + ".";
  CHECK_EQ(refusal(none), std::string("wrong_algorithm"));
  CHECK_EQ(refusal(token(claims, with(rk::header(), "alg", "HS256"))),
           std::string("wrong_algorithm"));
  CHECK_EQ(refusal(token(claims, with(rk::header(), "alg", 256))), std::string("wrong_algorithm"));
  CHECK_EQ(refusal(token(claims, without(rk::header(), "alg"))), std::string("wrong_algorithm"));
  CHECK_EQ(refusal(token(claims, with(rk::header(), "crit", nlohmann::json::array({"exp"})))),
           std::string("unsupported_header"));
}

TEST("the key id must name a known key") {
  const auto claims = rk::valid_claims();
  CHECK_EQ(refusal(token(claims, rk::header("rotated-away"))), std::string("unknown_key"));
  CHECK_EQ(refusal(token(claims, without(rk::header(), "kid"))), std::string("missing_kid"));
}

TEST("a token signed by another key, or altered, is refused") {
  const rk::SigningKey other;
  CHECK_EQ(refusal(other.sign(rk::header(), rk::valid_claims())), std::string("bad_signature"));
  // Swap in a payload with another user, keeping the original signature.
  const auto good = token(rk::valid_claims("alice"));
  const auto parts_end = good.find('.');
  const auto sig_start = good.rfind('.');
  const auto forged = good.substr(0, parts_end) + "." +
                      rk::b64url(rk::valid_claims("mallory").dump()) + good.substr(sig_start);
  CHECK_EQ(refusal(forged), std::string("bad_signature"));
  // A signature one byte short.
  const auto sig = rakia::base64url_decode(good.substr(sig_start + 1));
  CHECK_EQ(refusal(good.substr(0, sig_start + 1) + rk::b64url(sig.substr(0, sig.size() - 1))),
           std::string("bad_signature"));
}

TEST("malformed tokens are refused before any parsing work") {
  CHECK_EQ(refusal(""), std::string("malformed"));
  CHECK_EQ(refusal("abc"), std::string("malformed"));
  CHECK_EQ(refusal("a.b"), std::string("malformed"));
  CHECK_EQ(refusal("a.b.c.d"), std::string("malformed"));
  CHECK_EQ(refusal("!!!.e30.sig"), std::string("malformed"));
  CHECK_EQ(refusal(rk::b64url("not json") + ".e30.c2ln"), std::string("malformed"));
  CHECK_EQ(refusal(rk::b64url("[1,2]") + ".e30.c2ln"), std::string("malformed"));
  CHECK_EQ(refusal(std::string(FirebaseVerifier::kMaxTokenBytes + 1, 'a')),
           std::string("malformed"));
}

TEST("base64url: canonical, unpadded, url-safe alphabet only") {
  CHECK_EQ(rakia::base64url_decode("aGVsbG8"), std::string("hello"));
  CHECK_EQ(rakia::base64url_decode("_-8"), std::string("\xff\xef", 2));
  CHECK_THROWS(AuthError, rakia::base64url_decode("aGVsbG8="));
  CHECK_THROWS(AuthError, rakia::base64url_decode("a+b/"));
  CHECK_THROWS(AuthError, rakia::base64url_decode("a"));
  CHECK_THROWS(AuthError, rakia::base64url_decode("aGVsbG9"));  // non-zero spare bits
}

TEST("certificates: RSA of at least 2048 bits only") {
  CHECK_THROWS(AuthError, rakia::key_from_certificate_pem("not a certificate"));
  CHECK_THROWS(AuthError, rakia::key_from_certificate_pem(rk::SigningKey(1024).certificate_pem));
  CHECK(rakia::key_from_certificate_pem(signing_key().certificate_pem) != nullptr);
}

TEST("Cache-Control max-age") {
  CHECK(rakia::cache_max_age("public, max-age=19146, must-revalidate") ==
        std::optional<std::int64_t>(19146));
  CHECK(!rakia::cache_max_age("no-store").has_value());
  CHECK(!rakia::cache_max_age("max-age=abc").has_value());
}

TEST("Google's published certificates parse (network; RAKIA_API_NETWORK_TESTS=1)") {
#if defined(_MSC_VER)
  char* v = nullptr;
  std::size_t n = 0;
  const bool enabled = _dupenv_s(&v, &n, "RAKIA_API_NETWORK_TESTS") == 0 && v != nullptr &&
                       std::string(v) == "1";
  std::free(v);
#else
  const char* v = std::getenv("RAKIA_API_NETWORK_TESTS");
  const bool enabled = v != nullptr && std::string(v) == "1";
#endif
  if (!enabled) return;
  rakia::GoogleKeys google;
  google.refresh();
  // A real Firebase token header names one of these keys; an unknown one is
  // refused without crashing or blocking.
  FirebaseVerifier v2("some-project", google);
  try {
    v2.verify(token(rk::valid_claims(), rk::header("not-a-google-key")));
    CHECK(false);
  } catch (const AuthError& e) {
    CHECK_EQ(e.reason, std::string("unknown_key"));
  }
}

TEST("emulator tokens: unsigned, alg none, same claim checks; signed tokens refused") {
  const rakia::EmulatorVerifier emu(rk::kProject, [] { return rk::kNow; });
  const auto unsigned_token = [](const nlohmann::json& claims) {
    return rk::b64url(nlohmann::json{{"alg", "none"}, {"typ", "JWT"}}.dump()) + "." +
           rk::b64url(claims.dump()) + ".";
  };
  CHECK_EQ(emu.verify(unsigned_token(rk::valid_claims("emu-1"))).uid, std::string("emu-1"));

  const auto reason = [&](const std::string& t) {
    try {
      emu.verify(t);
    } catch (const AuthError& e) {
      return e.reason;
    }
    return std::string("accepted");
  };
  CHECK_EQ(reason(unsigned_token(with(rk::valid_claims(), "aud", "other-project"))),
           std::string("wrong_audience"));
  CHECK_EQ(reason(unsigned_token(with(rk::valid_claims(), "exp", rk::kNow - 3600))),
           std::string("expired"));
  // A real (signed) token is not an emulator token, and an alg none token
  // with a signature is refused.
  CHECK_EQ(reason(token(rk::valid_claims())), std::string("not_emulator_token"));
  CHECK_EQ(reason(unsigned_token(rk::valid_claims()) + "c2ln"), std::string("not_emulator_token"));
  // And the production verifier still refuses emulator tokens.
  CHECK_EQ(refusal(unsigned_token(rk::valid_claims())), std::string("wrong_algorithm"));
}

int main() {
  rakia::log::set_enabled(false);
  return rk::run("auth");
}
