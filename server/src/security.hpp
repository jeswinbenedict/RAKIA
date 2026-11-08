// SPDX-License-Identifier: Apache-2.0
#pragma once

#include <string>
#include <utility>
#include <vector>

#include "config.hpp"

namespace rakia {

/// Headers on every response. The API serves JSON only, so the policy
/// forbids everything a browser could do with a response as a document.
/// HSTS is sent outside development, where TLS terminates in front of it.
std::vector<std::pair<std::string, std::string>> security_headers(Environment env);

/// A random 128-bit request id, as 32 hex characters.
std::string new_request_id();

/// A random UUID version 7 (RFC 9562), canonical lower-case form.
std::string new_uuid_v7();

/// Accepts a caller-supplied X-Request-Id only if it is 8 to 64 characters
/// of [A-Za-z0-9-], so it is safe to log and echo.
bool is_safe_request_id(const std::string& id);

}  // namespace rakia
