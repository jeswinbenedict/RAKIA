# SPDX-License-Identifier: Apache-2.0
cmake_minimum_required(VERSION 3.24)
project(rakia_api VERSION 0.1.0 LANGUAGES CXX)

option(RAKIA_API_BUILD_TESTS "Build the API tests" ON)
option(RAKIA_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" ON)
option(RAKIA_SANITIZE "Build with AddressSanitizer (+UBSan on GCC/Clang)" OFF)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include(cmake/dependencies.cmake)
find_package(PostgreSQL REQUIRED)
find_package(OpenSSL 3.0 REQUIRED)
find_package(Threads REQUIRED)

# Strict warnings for RAKIA's own code; third-party headers are SYSTEM.
function(rakia_api_harden target)
  if(MSVC)
    target_compile_options(${target} PRIVATE /W4 /permissive- /utf-8 /EHsc
      /external:W0 /external:anglebrackets)
    target_compile_definitions(${target} PRIVATE _WIN32_WINNT=0x0A00 NOMINMAX
      WIN32_LEAN_AND_MEAN)
    if(RAKIA_WARNINGS_AS_ERRORS)
      target_compile_options(${target} PRIVATE /WX)
    endif()
    if(RAKIA_SANITIZE)
      target_compile_options(${target} PRIVATE /fsanitize=address /Zi)
      target_link_options(${target} PRIVATE /INCREMENTAL:NO)
    endif()
  else()
    target_compile_options(${target} PRIVATE
      -Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wsign-conversion
      -Wnon-virtual-dtor -Wold-style-cast -Wcast-qual -Wformat=2
      -Wnull-dereference)
    if(RAKIA_WARNINGS_AS_ERRORS)
      target_compile_options(${target} PRIVATE -Werror)
    endif()
    if(RAKIA_SANITIZE)
      target_compile_options(${target} PRIVATE
        -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer -g)
      target_link_options(${target} PRIVATE -fsanitize=address,undefined)
    endif()
  endif()
endfunction()

# Everything but main(), so the tests exercise the same code the binary runs.
add_library(rakia_api_core STATIC
  src/app.cpp
  src/config.cpp
  src/cors.cpp
  src/firebase_auth.cpp
  src/log.cpp
  src/pg_store.cpp
  src/rate_limit.cpp
  src/security.cpp
  src/space_weather.cpp
  src/turnstile.cpp)
target_include_directories(rakia_api_core PUBLIC src)
target_link_libraries(rakia_api_core PUBLIC
  rakia_httplib rakia_json PostgreSQL::PostgreSQL OpenSSL::SSL OpenSSL::Crypto
  Threads::Threads)
# HTTPS client support in cpp-httplib (for Google's token certificates); the
# server itself still speaks plain HTTP behind a TLS-terminating front end.
target_compile_definitions(rakia_api_core PUBLIC
  RAKIA_API_VERSION="${PROJECT_VERSION}" CPPHTTPLIB_OPENSSL_SUPPORT)
if(WIN32)
  target_link_libraries(rakia_api_core PUBLIC ws2_32 crypt32)
endif()
rakia_api_harden(rakia_api_core)

add_executable(rakia-api src/main.cpp)
target_link_libraries(rakia-api PRIVATE rakia_api_core)
rakia_api_harden(rakia-api)

install(TARGETS rakia-api RUNTIME DESTINATION bin)

if(RAKIA_API_BUILD_TESTS)
  enable_testing()
  set(RAKIA_API_TESTS test_config test_cors test_rate_limit test_auth test_http test_pg
    test_space_weather
    test_turnstile)
  foreach(t IN LISTS RAKIA_API_TESTS)
    add_executable(${t} tests/${t}.cpp)
    target_link_libraries(${t} PRIVATE rakia_api_core)
    rakia_api_harden(${t})
    if(NOT MSVC)
      # Tests read httplib::Result through operator->, which GCC cannot
      # prove non-null at -O2; production code keeps the warning.
      target_compile_options(${t} PRIVATE -Wno-null-dereference)
    endif()
    add_test(NAME ${t} COMMAND ${t})
  endforeach()
  if(WIN32)
    # libpq.dll and its dependencies live next to the PostgreSQL binaries.
    cmake_path(GET PostgreSQL_LIBRARY PARENT_PATH _pg_lib)
    cmake_path(GET _pg_lib PARENT_PATH _pg_root)
    set_tests_properties(${RAKIA_API_TESTS} PROPERTIES
      ENVIRONMENT_MODIFICATION "PATH=path_list_prepend:${_pg_root}/bin")
  endif()
endif()
