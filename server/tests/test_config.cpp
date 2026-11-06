// SPDX-License-Identifier: Apache-2.0
// Configuration: defaults, validation, stricter rules outside development,
// and that nothing secret is ever printed.
#include <cstdio>
#include <fstream>

#include "config.hpp"
#include "rk_test.hpp"

using rakia::ConfigError;
using rakia::EnvMap;
using rakia::load_config;

namespace {
EnvMap base() {
  return {{"RAKIA_DB_HOST", "localhost"},  {"RAKIA_DB_PORT", "5432"},
          {"RAKIA_DB_NAME", "rakia"},      {"RAKIA_DB_USER", "rakia_api"},
          {"RAKIA_DB_PASSWORD", "s3cret-value-never-logged"}};
}
EnvMap with(EnvMap m, const std::string& k, const std::string& v) {
  m[k] = v;
  return m;
}
}  // namespace

TEST("development defaults") {
  const auto c = load_config({}, base());
  CHECK(c.environment == rakia::Environment::development);
  CHECK_EQ(c.api_host, std::string("127.0.0.1"));
  CHECK_EQ(c.api_port, 8080);
  CHECK_EQ(c.db_sslmode, std::string("disable"));
  CHECK_EQ(c.db_pool_size, std::size_t{4});
  CHECK(c.cors_origins.empty());
}

TEST("the process environment wins over the .env file") {
  const auto c = load_config(with(base(), "RAKIA_API_PORT", "9000"),
                             {{"RAKIA_API_PORT", "9100"}});
  CHECK_EQ(c.api_port, 9100);
}

TEST("PORT is used when RAKIA_API_PORT is not set (Cloud Run)") {
  CHECK_EQ(load_config({}, with(base(), "PORT", "8081")).api_port, 8081);
  CHECK_EQ(load_config({}, with(with(base(), "PORT", "8081"), "RAKIA_API_PORT", "8082")).api_port,
           8082);
}

TEST("a missing database setting names the variable") {
  auto m = base();
  m.erase("RAKIA_DB_PASSWORD");
  try {
    load_config({}, m);
    CHECK(false);
  } catch (const ConfigError& e) {
    CHECK(std::string(e.what()).find("RAKIA_DB_PASSWORD") != std::string::npos);
  }
}

TEST("numbers are validated") {
  CHECK_THROWS(ConfigError, load_config({}, with(base(), "RAKIA_API_PORT", "0")));
  CHECK_THROWS(ConfigError, load_config({}, with(base(), "RAKIA_API_PORT", "70000")));
  CHECK_THROWS(ConfigError, load_config({}, with(base(), "RAKIA_API_PORT", "80a")));
  CHECK_THROWS(ConfigError, load_config({}, with(base(), "RAKIA_DB_PORT", "-1")));
  CHECK_THROWS(ConfigError, load_config({}, with(base(), "RAKIA_API_DB_POOL_SIZE", "0")));
  CHECK_THROWS(ConfigError, load_config({}, with(base(), "RAKIA_TRUSTED_PROXY_HOPS", "9")));
}

TEST("CORS origins must be bare origins") {
  CHECK_THROWS(ConfigError,
               load_config({}, with(base(), "RAKIA_CORS_ORIGINS", "https://a.example/path")));
  CHECK_THROWS(ConfigError, load_config({}, with(base(), "RAKIA_CORS_ORIGINS", "a.example")));
  CHECK_THROWS(ConfigError, load_config({}, with(base(), "RAKIA_CORS_ORIGINS", "ftp://a.example")));
  const auto c = load_config(
      {}, with(base(), "RAKIA_CORS_ORIGINS", " http://localhost:5000 , https://a.example "));
  CHECK_EQ(c.cors_origins.size(), std::size_t{2});
  CHECK_EQ(c.cors_origins[1], std::string("https://a.example"));
}

TEST("outside development: TLS to the database and public https origins only") {
  auto prod = with(base(), "RAKIA_ENV", "production");
  CHECK_THROWS(ConfigError, load_config({}, prod));  // sslmode disable
  prod = with(prod, "RAKIA_DB_SSLMODE", "require");
  CHECK_THROWS(ConfigError, load_config({}, prod));  // require is not enough
  prod = with(prod, "RAKIA_DB_SSLMODE", "verify-full");
  CHECK(load_config({}, prod).environment == rakia::Environment::production);
  CHECK_THROWS(ConfigError, load_config({}, with(prod, "RAKIA_CORS_ORIGINS", "http://a.example")));
  CHECK_THROWS(ConfigError,
               load_config({}, with(prod, "RAKIA_CORS_ORIGINS", "https://localhost:5000")));
  CHECK_THROWS(ConfigError, load_config({}, with(base(), "RAKIA_ENV", "prod")));
}

TEST("the API refuses to run as the migrator or a superuser") {
  CHECK_THROWS(ConfigError, load_config({}, with(base(), "RAKIA_DB_USER", "rakia_migrator")));
  CHECK_THROWS(ConfigError, load_config({}, with(base(), "RAKIA_DB_USER", "postgres")));
}

TEST("describe() never contains the password") {
  const auto c = load_config({}, base());
  CHECK(c.describe().find("s3cret") == std::string::npos);
  CHECK(c.describe().find("rakia_api@localhost:5432/rakia") != std::string::npos);
}

TEST(".env files: comments, blanks and whitespace") {
  const char* path = "rakia_test_config.env";
  {
    std::ofstream f(path);
    f << "# comment\n\nRAKIA_DB_HOST = db.local \nBROKEN\n=nokey\nRAKIA_DB_PORT=6543\r\n";
  }
  const auto m = rakia::read_env_file(path);
  std::remove(path);
  CHECK_EQ(m.at("RAKIA_DB_HOST"), std::string("db.local"));
  CHECK_EQ(m.at("RAKIA_DB_PORT"), std::string("6543"));
  CHECK_EQ(m.size(), std::size_t{2});
  CHECK(rakia::read_env_file("does-not-exist.env").empty());
}

RK_MAIN("config")
