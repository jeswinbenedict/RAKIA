// SPDX-License-Identifier: Apache-2.0
//
// Real RS256 tokens for tests: a freshly generated RSA key, wrapped in a
// self-signed X.509 certificate (the format Google publishes), and JWTs
// signed with it. Nothing here is a fake: the verifier under test runs its
// production code path against these keys.
#pragma once

#include <openssl/bio.h>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/x509.h>

#include <memory>
#include <nlohmann/json.hpp>
#include <stdexcept>
#include <string>

#include "firebase_auth.hpp"

namespace rk {

inline std::string b64url(const std::string& in) {
  static constexpr char table[] =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
  std::string out;
  std::uint32_t buffer = 0;
  int bits = 0;
  for (const char ch : in) {
    buffer = (buffer << 8) | static_cast<unsigned char>(ch);
    bits += 8;
    while (bits >= 6) {
      bits -= 6;
      out.push_back(table[(buffer >> bits) & 0x3Fu]);
    }
  }
  if (bits > 0) out.push_back(table[(buffer << (6 - bits)) & 0x3Fu]);
  return out;
}

/// An RSA signing key and its certificate.
struct SigningKey {
  std::shared_ptr<EVP_PKEY> key;
  std::string certificate_pem;

  explicit SigningKey(unsigned bits = 2048) {
    key.reset(EVP_PKEY_Q_keygen(nullptr, nullptr, "RSA", static_cast<size_t>(bits)),
              &EVP_PKEY_free);
    if (!key) throw std::runtime_error("RSA key generation failed");
    std::unique_ptr<X509, decltype(&X509_free)> cert(X509_new(), &X509_free);
    X509_set_version(cert.get(), 2);
    ASN1_INTEGER_set(X509_get_serialNumber(cert.get()), 1);
    X509_gmtime_adj(X509_getm_notBefore(cert.get()), 0);
    X509_gmtime_adj(X509_getm_notAfter(cert.get()), 3600);
    X509_set_pubkey(cert.get(), key.get());
    X509_NAME* name = X509_get_subject_name(cert.get());
    X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_ASC,
                               reinterpret_cast<const unsigned char*>("rakia-test"), -1, -1, 0);
    X509_set_issuer_name(cert.get(), name);
    if (X509_sign(cert.get(), key.get(), EVP_sha256()) == 0) {
      throw std::runtime_error("certificate signing failed");
    }
    std::unique_ptr<BIO, decltype(&BIO_free)> bio(BIO_new(BIO_s_mem()), &BIO_free);
    PEM_write_bio_X509(bio.get(), cert.get());
    char* data = nullptr;
    const long len = BIO_get_mem_data(bio.get(), &data);
    certificate_pem.assign(data, static_cast<std::size_t>(len));
  }

  /// header.payload.signature, signed with RS256.
  std::string sign(const nlohmann::json& header, const nlohmann::json& payload) const {
    const auto signing_input = b64url(header.dump()) + "." + b64url(payload.dump());
    std::unique_ptr<EVP_MD_CTX, decltype(&EVP_MD_CTX_free)> ctx(EVP_MD_CTX_new(),
                                                                 &EVP_MD_CTX_free);
    std::size_t len = 0;
    EVP_DigestSignInit(ctx.get(), nullptr, EVP_sha256(), nullptr, key.get());
    EVP_DigestSign(ctx.get(), nullptr, &len,
                   reinterpret_cast<const unsigned char*>(signing_input.data()),
                   signing_input.size());
    std::string sig(len, '\0');
    EVP_DigestSign(ctx.get(), reinterpret_cast<unsigned char*>(sig.data()), &len,
                   reinterpret_cast<const unsigned char*>(signing_input.data()),
                   signing_input.size());
    sig.resize(len);
    return signing_input + "." + b64url(sig);
  }
};

inline constexpr const char* kProject = "rakia-test-project";
inline constexpr std::int64_t kNow = 1'800'000'000;

/// Claims of a valid ID token for [uid] at kNow.
inline nlohmann::json valid_claims(const std::string& uid = "user-123") {
  return {{"iss", std::string("https://securetoken.google.com/") + kProject},
          {"aud", kProject},
          {"auth_time", kNow - 600},
          {"user_id", uid},
          {"sub", uid},
          {"iat", kNow - 60},
          {"exp", kNow + 3540},
          {"firebase", {{"sign_in_provider", "password"}}}};
}

inline nlohmann::json header(const std::string& kid = "key-1") {
  return {{"alg", "RS256"}, {"kid", kid}, {"typ", "JWT"}};
}

}  // namespace rk
