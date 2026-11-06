# SPDX-License-Identifier: Apache-2.0
cmake_minimum_required(VERSION 3.20)
project(librakia VERSION 0.1.0 LANGUAGES C)

option(RAKIA_BUILD_TESTS "Build librakia tests" ON)
option(RAKIA_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" ON)
option(RAKIA_SANITIZE "Build with AddressSanitizer (+UBSan on GCC/Clang)" OFF)
option(RAKIA_FUZZ "Build the libFuzzer target (Clang only)" OFF)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Strict, deterministic floating point and warnings for every librakia target.
function(rakia_harden target)
  if(MSVC)
    target_compile_options(${target} PRIVATE /W4 /fp:precise /permissive- /utf-8)
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
      -Wstrict-prototypes -Wmissing-prototypes -Wcast-qual -Wformat=2
      -ffp-contract=off -fno-fast-math)
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

add_library(rakia
  src/assess.c
  src/baseline.c
  src/cusum.c
  src/flat.c
  src/ledger.c
  src/multivariate.c
  src/quality.c
  src/sha256.c
  src/stats.c
  src/status.c
  src/trend.c)
add_library(rakia::rakia ALIAS rakia)
target_include_directories(rakia PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>)
set_target_properties(rakia PROPERTIES
  VERSION ${PROJECT_VERSION}
  SOVERSION ${PROJECT_VERSION_MAJOR}
  C_VISIBILITY_PRESET hidden)
if(BUILD_SHARED_LIBS)
  target_compile_definitions(rakia PUBLIC RAKIA_SHARED PRIVATE RAKIA_BUILDING)
endif()
if(UNIX)
  target_link_libraries(rakia PUBLIC m)
endif()
rakia_harden(rakia)

install(TARGETS rakia ARCHIVE DESTINATION lib LIBRARY DESTINATION lib RUNTIME DESTINATION bin)
install(DIRECTORY include/ DESTINATION include)

if(RAKIA_BUILD_TESTS)
  enable_testing()
  set(RAKIA_TESTS
    test_stats test_quality_baseline test_cusum test_trend test_multivariate
    test_ledger test_assess test_validation test_flat)
  foreach(t IN LISTS RAKIA_TESTS)
    add_executable(${t} tests/${t}.c)
    target_link_libraries(${t} PRIVATE rakia)
    rakia_harden(${t})
    add_test(NAME ${t} COMMAND ${t})
  endforeach()
endif()

if(RAKIA_FUZZ)
  if(NOT CMAKE_C_COMPILER_ID MATCHES "Clang")
    message(FATAL_ERROR "RAKIA_FUZZ requires Clang")
  endif()
  add_executable(fuzz_core fuzz/fuzz_core.c)
  target_link_libraries(fuzz_core PRIVATE rakia)
  target_compile_options(fuzz_core PRIVATE -fsanitize=fuzzer,address,undefined -g)
  target_link_options(fuzz_core PRIVATE -fsanitize=fuzzer,address,undefined)
endif()
