// SPDX-License-Identifier: Apache-2.0
#include "cors.hpp"

#include <algorithm>
#include <cctype>
#include <sstream>

namespace rakia {
namespace {

std::string lower_trim(std::string s) {
  const auto first = s.find_first_not_of(" \t");
  if (first == std::string::npos) return {};
  s = s.substr(first, s.find_last_not_of(" \t") - first + 1);
  std::transform(s.begin(), s.end(), s.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return s;
}

}  // namespace

bool Cors::allows(const std::string& origin) const {
  return std::find(allowed_.begin(), allowed_.end(), origin) != allowed_.end();
}

std::vector<std::pair<std::string, std::string>> Cors::response_headers(
    const std::optional<std::string>& origin) const {
  // Vary: Origin always, so caches never hand one origin's answer to another.
  std::vector<std::pair<std::string, std::string>> h{{"Vary", "Origin"}};
  if (origin && allows(*origin)) {
    h.emplace_back("Access-Control-Allow-Origin", *origin);
    h.emplace_back("Access-Control-Expose-Headers", "X-Request-Id, Retry-After");
  }
  return h;
}

std::optional<std::vector<std::pair<std::string, std::string>>> Cors::preflight(
    const std::string& origin, const std::string& method,
    const std::string& request_headers) const {
  if (!allows(origin)) return std::nullopt;
  if (method != "GET" && method != "POST") return std::nullopt;

  std::istringstream allowed_in(allowed_headers);
  std::vector<std::string> allowed;
  for (std::string item; std::getline(allowed_in, item, ',');) allowed.push_back(lower_trim(item));
  std::istringstream requested(request_headers);
  for (std::string item; std::getline(requested, item, ',');) {
    const auto name = lower_trim(item);
    if (!name.empty() && std::find(allowed.begin(), allowed.end(), name) == allowed.end()) {
      return std::nullopt;
    }
  }
  return std::vector<std::pair<std::string, std::string>>{
      {"Vary", "Origin"},
      {"Access-Control-Allow-Origin", origin},
      {"Access-Control-Allow-Methods", allowed_methods},
      {"Access-Control-Allow-Headers", allowed_headers},
      {"Access-Control-Max-Age", "600"},
  };
}

}  // namespace rakia
