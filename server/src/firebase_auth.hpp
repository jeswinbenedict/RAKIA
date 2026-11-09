// SPDX-License-Identifier: Apache-2.0
#pragma once

#include <chrono>
#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <stdexcept>
#include <string>
#include <string_view>

struct evp_pkey_st;

namespace rakia {

using PublicKey = std::shared_ptr<evp_pkey_st>;

/// A Firebase ID token that passed every check.
struct VerifiedUser {
  std::string uid;
  std::int64_t issued_at = 0;
  std::int64_t expires_at = 0;
  std::int64_t auth_time = 0;
};

/// A token was refused. [reason] is a short code that is safe to log; it
/// never contains the token or its claims.
class AuthError : public std::runtime_error {
 public:
  explicit AuthError(std::string code)
      : std::runtime_error("token refused: " + code), reason(std::move(code)) {}
  std::string reason;
};

/// The public key from a PEM-encoded X.509 certificate. Throws AuthError
/// ("bad_certificate") if it is not an RSA certificate.
PublicKey key_from_certificate_pem(const std::string& pem);

/// The keys that may have signed ID tokens, by key id ("kid").
class PublicKeys {
 public:
  virtual ~PublicKeys() = default;
  /// The key for [kid], or null when there is none.
  virtual PublicKey find(const std::string& kid) = 0;
};

/// A fixed set of keys (tests, or keys pinned by configuration).
class StaticKeys final : public PublicKeys {
 public:
  void add(const std::string& kid, PublicKey key) { keys_[kid] = std::move(key); }
  PublicKey find(const std::string& kid) override;

 private:
  std::map<std::string, PublicKey> keys_;
};

/// Google's published certificates for Firebase ID tokens, fetched over
/// HTTPS (with certificate verification) and cached for as long as the
/// response's Cache-Control max-age allows. An unknown key id triggers a
/// refresh, at most once a minute, so a rotated key is picked up promptly.
class GoogleKeys final : public PublicKeys {
 public:
  static constexpr const char* kHost = "www.googleapis.com";
  static constexpr const char* kPath =
      "/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com";

  PublicKey find(const std::string& kid) override;

  /// Downloads the certificates now. Throws AuthError ("keys_unavailable")
  /// when they cannot be fetched or parsed.
  void refresh();

 private:
  std::mutex mutex_;
  std::map<std::string, PublicKey> keys_;
  std::chrono::steady_clock::time_point expires_{};
  std::chrono::steady_clock::time_point last_attempt_{};
};

/// The seconds of a Cache-Control max-age directive, or nullopt.
std::optional<std::int64_t> cache_max_age(std::string_view cache_control);

/// Checks a bearer token and names the user it belongs to.
class TokenVerifier {
 public:
  virtual ~TokenVerifier() = default;
  /// Throws AuthError when the token must be refused.
  virtual VerifiedUser verify(std::string_view token) const = 0;
};

/// Verifies Firebase ID tokens for one project, as the Firebase
/// documentation requires for third-party verification: RS256 signed by a
/// current Google key; aud is the project id; iss is
/// https://securetoken.google.com/<project id>; exp in the future; iat and
/// auth_time in the past; sub a non-empty string of at most 128 characters.
class FirebaseVerifier final : public TokenVerifier {
 public:
  using Clock = std::function<std::int64_t()>;  // seconds since the epoch

  FirebaseVerifier(std::string project_id, PublicKeys& keys, Clock now = {});

  /// Throws AuthError when the token must be refused.
  VerifiedUser verify(std::string_view token) const override;

  const std::string& project_id() const { return project_id_; }

  /// Tolerated clock difference between Google's servers and this one.
  static constexpr std::int64_t kLeewaySeconds = 60;
  /// Longest token accepted, to bound parsing work.
  static constexpr std::size_t kMaxTokenBytes = 8192;

 private:
  std::string project_id_;
  std::string issuer_;
  PublicKeys& keys_;
  Clock now_;
};

/// Verifies the unsigned ID tokens issued by the Firebase Auth emulator
/// (header alg "none", empty signature), with the same claim checks as
/// FirebaseVerifier. For local development only: configuration refuses the
/// emulator outside development, because anyone can forge these tokens.
class EmulatorVerifier final : public TokenVerifier {
 public:
  EmulatorVerifier(std::string project_id, FirebaseVerifier::Clock now = {});
  VerifiedUser verify(std::string_view token) const override;

 private:
  std::string project_id_;
  std::string issuer_;
  FirebaseVerifier::Clock now_;
};

/// Decodes base64url without padding, as used by JWTs. Throws AuthError
/// ("malformed") on any other character or length.
std::string base64url_decode(std::string_view in);

}  // namespace rakia
