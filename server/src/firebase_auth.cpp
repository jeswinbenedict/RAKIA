// SPDX-License-Identifier: Apache-2.0
#include "firebase_auth.hpp"

#include <httplib.h>
#include <openssl/bio.h>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/x509.h>

#include <algorithm>
#include <cctype>
#include <charconv>
#include <memory>
#include <nlohmann/json.hpp>

#include "log.hpp"

namespace rakia {
namespace {

using json = nlohmann::json;

int decode_char(char c) {
  if (c >= 'A' && c <= 'Z') return c - 'A';
  if (c >= 'a' && c <= 'z') return c - 'a' + 26;
  if (c >= '0' && c <= '9') return c - '0' + 52;
  if (c == '-') return 62;
  if (c == '_') return 63;
  return -1;
}

std::int64_t now_seconds() {
  return std::chrono::duration_cast<std::chrono::seconds>(
             std::chrono::system_clock::now().time_since_epoch())
      .count();
}

std::int64_t integer_claim(const json& claims, const char* name) {
  const auto it = claims.find(name);
  if (it == claims.end() || !it->is_number_integer()) {
    throw AuthError(std::string("missing_") + name);
  }
  return it->get<std::int64_t>();
}

std::string string_claim(const json& claims, const char* name) {
  const auto it = claims.find(name);
  if (it == claims.end() || !it->is_string()) throw AuthError(std::string("missing_") + name);
  return it->get<std::string>();
}

json parse_object(const std::string& text) {
  json value = json::parse(text, nullptr, /*allow_exceptions=*/false);
  if (!value.is_object()) throw AuthError("malformed");
  return value;
}

/// The claim checks shared by both verifiers.
VerifiedUser check_claims(const json& claims, const std::string& project_id,
                          const std::string& issuer, std::int64_t now) {
  constexpr auto kLeewaySeconds = FirebaseVerifier::kLeewaySeconds;
  VerifiedUser user;
  user.expires_at = integer_claim(claims, "exp");
  user.issued_at = integer_claim(claims, "iat");
  user.auth_time = integer_claim(claims, "auth_time");
  if (user.expires_at + kLeewaySeconds <= now) throw AuthError("expired");
  if (user.issued_at > now + kLeewaySeconds) throw AuthError("issued_in_future");
  if (user.auth_time > now + kLeewaySeconds) throw AuthError("auth_time_in_future");
  if (string_claim(claims, "aud") != project_id) throw AuthError("wrong_audience");
  if (string_claim(claims, "iss") != issuer) throw AuthError("wrong_issuer");
  user.uid = string_claim(claims, "sub");
  if (user.uid.empty() || user.uid.size() > 128) throw AuthError("bad_subject");
  for (const char ch : user.uid) {
    if (std::iscntrl(static_cast<unsigned char>(ch))) throw AuthError("bad_subject");
  }
  return user;
}

}  // namespace

std::string base64url_decode(std::string_view in) {
  if (in.size() % 4 == 1) throw AuthError("malformed");
  std::string out;
  out.reserve(in.size() * 3 / 4);
  std::uint32_t buffer = 0;
  int bits = 0;
  for (const char c : in) {
    const int v = decode_char(c);
    if (v < 0) throw AuthError("malformed");
    buffer = (buffer << 6) | static_cast<std::uint32_t>(v);
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      out.push_back(static_cast<char>((buffer >> bits) & 0xFFu));
    }
  }
  // Leftover bits must be zero (canonical encoding).
  if (bits > 0 && (buffer & ((1u << bits) - 1u)) != 0) throw AuthError("malformed");
  return out;
}

PublicKey key_from_certificate_pem(const std::string& pem) {
  std::unique_ptr<BIO, decltype(&BIO_free)> bio(
      BIO_new_mem_buf(pem.data(), static_cast<int>(pem.size())), &BIO_free);
  if (!bio) throw AuthError("bad_certificate");
  std::unique_ptr<X509, decltype(&X509_free)> cert(
      PEM_read_bio_X509(bio.get(), nullptr, nullptr, nullptr), &X509_free);
  if (!cert) throw AuthError("bad_certificate");
  EVP_PKEY* key = X509_get_pubkey(cert.get());
  if (key == nullptr || EVP_PKEY_base_id(key) != EVP_PKEY_RSA || EVP_PKEY_get_bits(key) < 2048) {
    if (key != nullptr) EVP_PKEY_free(key);
    throw AuthError("bad_certificate");
  }
  return PublicKey(key, &EVP_PKEY_free);
}

PublicKey StaticKeys::find(const std::string& kid) {
  const auto it = keys_.find(kid);
  return it == keys_.end() ? nullptr : it->second;
}

std::optional<std::int64_t> cache_max_age(std::string_view cc) {
  const auto pos = cc.find("max-age=");
  if (pos == std::string_view::npos) return std::nullopt;
  const auto digits = cc.substr(pos + 8);
  std::int64_t value = 0;
  const auto [ptr, ec] = std::from_chars(digits.data(), digits.data() + digits.size(), value);
  if (ec != std::errc{} || ptr == digits.data() || value < 0) return std::nullopt;
  return value;
}

void GoogleKeys::refresh() {
  httplib::SSLClient client(kHost, 443);
  client.enable_server_certificate_verification(true);
  client.set_connection_timeout(std::chrono::seconds(5));
  client.set_read_timeout(std::chrono::seconds(5));
  const auto res = client.Get(kPath);
  if (!res || res->status != 200) {
    log::warn("could not fetch Google's token certificates",
              {{"status", res ? res->status : 0},
               {"error", res ? "" : httplib::to_string(res.error())}});
    throw AuthError("keys_unavailable");
  }
  const json body = json::parse(res->body, nullptr, false);
  if (!body.is_object() || body.empty()) throw AuthError("keys_unavailable");
  std::map<std::string, PublicKey> keys;
  for (const auto& [kid, pem] : body.items()) {
    if (!pem.is_string()) throw AuthError("keys_unavailable");
    keys[kid] = key_from_certificate_pem(pem.get<std::string>());
  }
  // Cache for the advertised lifetime, but never less than a minute or
  // more than a day.
  auto max_age = cache_max_age(res->get_header_value("Cache-Control")).value_or(3600);
  max_age = std::clamp<std::int64_t>(max_age, 60, 86400);
  const std::lock_guard<std::mutex> lock(mutex_);
  keys_ = std::move(keys);
  expires_ = std::chrono::steady_clock::now() + std::chrono::seconds(max_age);
}

PublicKey GoogleKeys::find(const std::string& kid) {
  const auto now = std::chrono::steady_clock::now();
  bool should_refresh = false;
  {
    const std::lock_guard<std::mutex> lock(mutex_);
    const bool expired = now >= expires_;
    const bool unknown = keys_.find(kid) == keys_.end();
    if ((expired || unknown) && now - last_attempt_ >= std::chrono::minutes(1)) {
      last_attempt_ = now;
      should_refresh = true;
    }
  }
  if (should_refresh) {
    try {
      refresh();
    } catch (const AuthError&) {
      // Keep serving the keys already known; an unknown kid is refused below.
    }
  }
  const std::lock_guard<std::mutex> lock(mutex_);
  const auto it = keys_.find(kid);
  return it == keys_.end() ? nullptr : it->second;
}

FirebaseVerifier::FirebaseVerifier(std::string project_id, PublicKeys& keys, Clock now)
    : project_id_(std::move(project_id)),
      issuer_("https://securetoken.google.com/" + project_id_),
      keys_(keys),
      now_(now ? std::move(now) : Clock(now_seconds)) {}

VerifiedUser FirebaseVerifier::verify(std::string_view token) const {
  if (token.empty() || token.size() > kMaxTokenBytes) throw AuthError("malformed");
  const auto dot1 = token.find('.');
  const auto dot2 = dot1 == std::string_view::npos ? dot1 : token.find('.', dot1 + 1);
  if (dot2 == std::string_view::npos || token.find('.', dot2 + 1) != std::string_view::npos) {
    throw AuthError("malformed");
  }
  const auto header_b64 = token.substr(0, dot1);
  const auto payload_b64 = token.substr(dot1 + 1, dot2 - dot1 - 1);
  const auto signature = base64url_decode(token.substr(dot2 + 1));

  const json header = parse_object(base64url_decode(header_b64));
  // Only RS256: never "none", never an HMAC algorithm keyed with a public key.
  const auto alg = header.find("alg");
  if (alg == header.end() || !alg->is_string() || alg->get<std::string>() != "RS256") {
    throw AuthError("wrong_algorithm");
  }
  if (header.contains("crit")) throw AuthError("unsupported_header");
  const auto kid_it = header.find("kid");
  if (kid_it == header.end() || !kid_it->is_string()) throw AuthError("missing_kid");
  const PublicKey key = keys_.find(kid_it->get<std::string>());
  if (!key) throw AuthError("unknown_key");

  // The signature covers the encoded header and payload exactly as sent.
  const auto signed_part = token.substr(0, dot2);
  std::unique_ptr<EVP_MD_CTX, decltype(&EVP_MD_CTX_free)> ctx(EVP_MD_CTX_new(),
                                                               &EVP_MD_CTX_free);
  if (!ctx ||
      EVP_DigestVerifyInit(ctx.get(), nullptr, EVP_sha256(), nullptr, key.get()) != 1 ||
      EVP_DigestVerify(ctx.get(), reinterpret_cast<const unsigned char*>(signature.data()),
                       signature.size(),
                       reinterpret_cast<const unsigned char*>(signed_part.data()),
                       signed_part.size()) != 1) {
    throw AuthError("bad_signature");
  }

  return check_claims(parse_object(base64url_decode(payload_b64)), project_id_, issuer_,
                      now_());
}

EmulatorVerifier::EmulatorVerifier(std::string project_id, FirebaseVerifier::Clock now)
    : project_id_(std::move(project_id)),
      issuer_("https://securetoken.google.com/" + project_id_),
      now_(now ? std::move(now) : FirebaseVerifier::Clock(now_seconds)) {}

VerifiedUser EmulatorVerifier::verify(std::string_view token) const {
  if (token.empty() || token.size() > FirebaseVerifier::kMaxTokenBytes) {
    throw AuthError("malformed");
  }
  const auto dot1 = token.find('.');
  const auto dot2 = dot1 == std::string_view::npos ? dot1 : token.find('.', dot1 + 1);
  if (dot2 == std::string_view::npos || token.find('.', dot2 + 1) != std::string_view::npos) {
    throw AuthError("malformed");
  }
  const json header = parse_object(base64url_decode(token.substr(0, dot1)));
  const auto alg = header.find("alg");
  if (alg == header.end() || !alg->is_string() || alg->get<std::string>() != "none" ||
      dot2 + 1 != token.size()) {
    throw AuthError("not_emulator_token");
  }
  return check_claims(parse_object(base64url_decode(token.substr(dot1 + 1, dot2 - dot1 - 1))),
                      project_id_, issuer_, now_());
}

}  // namespace rakia
