# SPDX-License-Identifier: Apache-2.0
#
# Third-party code, fetched at configure time from the projects' own GitHub
# releases and checked against the SHA-256 pinned here. Both are header-only
# and MIT licensed. Bumping a version means updating its hash; a mismatch
# stops the configure step.
include(FetchContent)

# Only the headers are used. SOURCE_SUBDIR names a directory without a
# CMakeLists.txt, so neither project's own build is configured.
FetchContent_Declare(cpp_httplib
  URL https://github.com/yhirose/cpp-httplib/archive/refs/tags/v0.62.0.tar.gz
  URL_HASH SHA256=7bba5949c56e772236432f69da03197fd4c12dc443455b9d81f6a05575431fc8
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE
  SOURCE_SUBDIR headers-only)

FetchContent_Declare(nlohmann_json
  URL https://github.com/nlohmann/json/releases/download/v3.12.0/json.tar.xz
  URL_HASH SHA256=42f6e95cad6ec532fd372391373363b62a14af6d771056dbfc86160e6dfff7aa
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE
  SOURCE_SUBDIR headers-only)

FetchContent_MakeAvailable(cpp_httplib nlohmann_json)

add_library(rakia_httplib INTERFACE)
target_include_directories(rakia_httplib SYSTEM INTERFACE ${cpp_httplib_SOURCE_DIR})
# No TLS inside the process: TLS terminates at the platform's front end
# (Cloud Run) or a local reverse proxy. No compression: not needed for JSON
# at these sizes and one less attack surface.

add_library(rakia_json INTERFACE)
target_include_directories(rakia_json SYSTEM INTERFACE ${nlohmann_json_SOURCE_DIR}/single_include)
