// SPDX-License-Identifier: Apache-2.0
#pragma once

#include <cstddef>
#include <cstdint>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>

namespace rakia {

enum class Environment { development, staging, production };

/// Settings, all from environment variables (see .env.example). Secrets are
/// held here but never printed: describe() omits them.
struct Config {
  Environment environment = Environment::development;

  std::string api_host = "127.0.0.1";
  std::uint16_t api_port = 8080;
  std::vector<std::string> cors_origins;
  /// Requests per minute per client address.
  std::uint32_t rate_limit_per_minute = 120;
  /// Reverse proxies in front of the API that append to X-Forwarded-For
  /// (1 on Cloud Run). 0 trusts no header and uses the socket address.
  std::uint32_t trusted_proxy_hops = 0;

  std::string db_host;
  std::uint16_t db_port = 5432;
  std::string db_name;
  std::string db_user;
  std::string db_password;
  std::string db_sslmode = "disable";
  /// Certificates that may sign the database server's certificate: a file
  /// path, or "system" for the operating system's trusted roots (the
  /// default with verify-full). Empty for other modes.
  std::string db_sslrootcert;
  std::size_t db_pool_size = 4;

  /// Firebase project whose ID tokens the API accepts. Empty in
  /// development means sign-in is not configured (authenticated endpoints
  /// answer 503); required everywhere else.
  std::string firebase_project_id;

  /// Settings safe to log: everything except the password.
  [[nodiscard]] std::string describe() const;
};

/// A setting that is missing or invalid. The message names the variable,
/// never its value (it may be a secret).
class ConfigError : public std::runtime_error {
 public:
  using std::runtime_error::runtime_error;
};

using EnvMap = std::map<std::string, std::string>;

/// `KEY=value` lines of a .env file; blank lines and # comments skipped.
/// A missing file yields an empty map.
EnvMap read_env_file(const std::string& path);

/// The process environment for the RAKIA_* variables and PORT.
EnvMap process_environment();

/// Builds and validates the configuration. [env] wins over [file].
/// Outside development, TLS to the database and https CORS origins are
/// required.
Config load_config(const EnvMap& file, const EnvMap& env);

}  // namespace rakia
