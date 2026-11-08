// SPDX-License-Identifier: Apache-2.0
#include "config.hpp"

#include <charconv>
#include <cstdlib>
#include <fstream>
#include <limits>
#include <sstream>
#include <system_error>

namespace rakia {
namespace {

std::string trim(const std::string& s) {
  const auto first = s.find_first_not_of(" \t\r\n");
  if (first == std::string::npos) return {};
  const auto last = s.find_last_not_of(" \t\r\n");
  return s.substr(first, last - first + 1);
}

template <typename T>
T parse_number(const std::string& key, const std::string& text, T min, T max) {
  T value{};
  const auto* begin = text.data();
  const auto* end = text.data() + text.size();
  const auto [ptr, ec] = std::from_chars(begin, end, value);
  if (text.empty() || ec != std::errc{} || ptr != end || value < min || value > max) {
    std::ostringstream m;
    m << key << " must be a whole number from " << +min << " to " << +max;
    throw ConfigError(m.str());
  }
  return value;
}

std::vector<std::string> split_list(const std::string& text) {
  std::vector<std::string> out;
  std::string item;
  std::istringstream in(text);
  while (std::getline(in, item, ',')) {
    item = trim(item);
    if (!item.empty()) out.push_back(item);
  }
  return out;
}

// An origin is scheme://host[:port] with nothing after it.
bool is_origin(const std::string& o) {
  const auto scheme = o.find("://");
  if (scheme == std::string::npos) return false;
  const auto s = o.substr(0, scheme);
  if (s != "http" && s != "https") return false;
  const auto rest = o.substr(scheme + 3);
  if (rest.empty() || rest.find_first_of("/?#@ ") != std::string::npos) return false;
  return true;
}

bool is_local(const std::string& origin) {
  return origin.find("://localhost") != std::string::npos ||
         origin.find("://127.0.0.1") != std::string::npos ||
         origin.find("://[::1]") != std::string::npos;
}

}  // namespace

EnvMap read_env_file(const std::string& path) {
  EnvMap values;
  std::ifstream in(path);
  if (!in) return values;
  std::string line;
  while (std::getline(in, line)) {
    line = trim(line);
    if (line.empty() || line.front() == '#') continue;
    const auto eq = line.find('=');
    if (eq == std::string::npos || eq == 0) continue;
    values[trim(line.substr(0, eq))] = trim(line.substr(eq + 1));
  }
  return values;
}

EnvMap process_environment() {
  static const char* const keys[] = {
      "RAKIA_ENV",          "RAKIA_API_HOST",
      "RAKIA_API_PORT",     "PORT",
      "RAKIA_CORS_ORIGINS", "RAKIA_API_RATE_LIMIT_PER_MINUTE",
      "RAKIA_TRUSTED_PROXY_HOPS",
      "RAKIA_DB_HOST",      "RAKIA_DB_PORT",
      "RAKIA_DB_NAME",      "RAKIA_DB_USER",
      "RAKIA_DB_PASSWORD",  "RAKIA_DB_SSLMODE",
      "RAKIA_DB_SSLROOTCERT",
      "RAKIA_API_DB_POOL_SIZE",
  };
  EnvMap env;
  for (const char* key : keys) {
#if defined(_MSC_VER)
    char* value = nullptr;
    std::size_t len = 0;
    if (_dupenv_s(&value, &len, key) == 0 && value != nullptr) {
      env[key] = value;
      std::free(value);
    }
#else
    if (const char* value = std::getenv(key)) env[key] = value;
#endif
  }
  return env;
}

Config load_config(const EnvMap& file, const EnvMap& env) {
  EnvMap all = file;
  for (const auto& [k, v] : env) all[k] = v;
  auto get = [&](const std::string& key) -> std::string {
    const auto it = all.find(key);
    return it == all.end() ? std::string{} : it->second;
  };
  auto need = [&](const std::string& key) -> std::string {
    auto v = get(key);
    if (v.empty()) {
      throw ConfigError(key + " is not set (see .env.example; for local development run "
                              "db/bootstrap/bootstrap-local.ps1 or .sh)");
    }
    return v;
  };

  Config c;
  const auto env_name = get("RAKIA_ENV").empty() ? "development" : get("RAKIA_ENV");
  if (env_name == "development") {
    c.environment = Environment::development;
  } else if (env_name == "staging") {
    c.environment = Environment::staging;
  } else if (env_name == "production") {
    c.environment = Environment::production;
  } else {
    throw ConfigError("RAKIA_ENV must be development, staging or production");
  }
  const bool dev = c.environment == Environment::development;

  if (!get("RAKIA_API_HOST").empty()) c.api_host = get("RAKIA_API_HOST");
  // Cloud Run provides PORT; RAKIA_API_PORT wins when both are set.
  if (!get("RAKIA_API_PORT").empty()) {
    c.api_port = parse_number<std::uint16_t>("RAKIA_API_PORT", get("RAKIA_API_PORT"), 1, 65535);
  } else if (!get("PORT").empty()) {
    c.api_port = parse_number<std::uint16_t>("PORT", get("PORT"), 1, 65535);
  }

  c.cors_origins = split_list(get("RAKIA_CORS_ORIGINS"));
  for (const auto& o : c.cors_origins) {
    if (!is_origin(o)) {
      throw ConfigError("RAKIA_CORS_ORIGINS must list origins such as "
                        "https://app.example.org, without paths");
    }
    if (!dev && (o.rfind("https://", 0) != 0 || is_local(o))) {
      throw ConfigError("RAKIA_CORS_ORIGINS may list only public https origins outside "
                        "development");
    }
  }

  if (!get("RAKIA_API_RATE_LIMIT_PER_MINUTE").empty()) {
    c.rate_limit_per_minute = parse_number<std::uint32_t>(
        "RAKIA_API_RATE_LIMIT_PER_MINUTE", get("RAKIA_API_RATE_LIMIT_PER_MINUTE"), 1, 100000);
  }
  if (!get("RAKIA_TRUSTED_PROXY_HOPS").empty()) {
    c.trusted_proxy_hops = parse_number<std::uint32_t>(
        "RAKIA_TRUSTED_PROXY_HOPS", get("RAKIA_TRUSTED_PROXY_HOPS"), 0, 5);
  }

  c.db_host = need("RAKIA_DB_HOST");
  c.db_port = parse_number<std::uint16_t>("RAKIA_DB_PORT", need("RAKIA_DB_PORT"), 1, 65535);
  c.db_name = need("RAKIA_DB_NAME");
  c.db_user = need("RAKIA_DB_USER");
  c.db_password = need("RAKIA_DB_PASSWORD");
  if (!get("RAKIA_DB_SSLMODE").empty()) c.db_sslmode = get("RAKIA_DB_SSLMODE");
  if (c.db_sslmode != "disable" && c.db_sslmode != "require" && c.db_sslmode != "verify-full") {
    throw ConfigError("RAKIA_DB_SSLMODE must be disable, require or verify-full");
  }
  if (!dev && c.db_sslmode != "verify-full") {
    throw ConfigError("RAKIA_DB_SSLMODE must be verify-full outside development");
  }
  c.db_sslrootcert = get("RAKIA_DB_SSLROOTCERT");
  if (c.db_sslmode == "verify-full" && c.db_sslrootcert.empty()) c.db_sslrootcert = "system";
  if (c.db_sslmode == "disable" && !c.db_sslrootcert.empty()) {
    throw ConfigError("RAKIA_DB_SSLROOTCERT is set but RAKIA_DB_SSLMODE is disable");
  }
  if (c.db_user == "rakia_migrator" || c.db_user == "postgres") {
    throw ConfigError("RAKIA_DB_USER must be the least-privilege API role (rakia_api), not "
                      "the migrator or a superuser");
  }
  if (!get("RAKIA_API_DB_POOL_SIZE").empty()) {
    c.db_pool_size = parse_number<std::size_t>("RAKIA_API_DB_POOL_SIZE",
                                               get("RAKIA_API_DB_POOL_SIZE"), 1, 64);
  }
  return c;
}

std::string Config::describe() const {
  std::ostringstream s;
  s << "env=" << (environment == Environment::development ? "development"
                  : environment == Environment::staging   ? "staging"
                                                          : "production")
    << " listen=" << api_host << ':' << api_port << " cors=";
  for (std::size_t i = 0; i < cors_origins.size(); ++i) s << (i ? "," : "") << cors_origins[i];
  s << " rate_limit=" << rate_limit_per_minute << "/min proxy_hops=" << trusted_proxy_hops
    << " db=" << db_user << '@' << db_host << ':' << db_port << '/' << db_name
    << " sslmode=" << db_sslmode
    << (db_sslrootcert.empty() ? "" : " sslrootcert=" + db_sslrootcert)
    << " pool=" << db_pool_size;
  return s.str();
}

}  // namespace rakia
