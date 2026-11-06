// SPDX-License-Identifier: Apache-2.0
//
// A minimal test harness, like librakia's: each test is a function; checks
// report file and line and the test binary exits non-zero on any failure.
#pragma once

#include <cstdio>
#include <exception>
#include <functional>
#include <string>
#include <utility>
#include <vector>

namespace rk {

inline int& failures() {
  static int n = 0;
  return n;
}

inline std::vector<std::pair<const char*, std::function<void()>>>& registry() {
  static std::vector<std::pair<const char*, std::function<void()>>> tests;
  return tests;
}

struct Register {
  Register(const char* name, std::function<void()> fn) { registry().emplace_back(name, std::move(fn)); }
};

inline void fail(const char* file, int line, const std::string& what) {
  ++failures();
  std::fprintf(stderr, "  FAIL %s:%d: %s\n", file, line, what.c_str());
}

/// Runs every registered test; returns the process exit code.
inline int run(const char* suite) {
  int failed_tests = 0;
  for (const auto& [name, fn] : registry()) {
    const int before = failures();
    try {
      fn();
    } catch (const std::exception& e) {
      fail(name, 0, std::string("unexpected exception: ") + e.what());
    } catch (...) {
      fail(name, 0, "unexpected non-standard exception");
    }
    const bool ok = failures() == before;
    if (!ok) ++failed_tests;
    std::printf("%s %s\n", ok ? "ok  " : "FAIL", name);
  }
  std::printf("%s: %zu tests, %d failed\n", suite, registry().size(), failed_tests);
  return failed_tests == 0 ? 0 : 1;
}

}  // namespace rk

#define RK_CAT2(a, b) a##b
#define RK_CAT(a, b) RK_CAT2(a, b)
#define TEST(name)                                                       \
  static void RK_CAT(test_fn_, __LINE__)();                              \
  static const rk::Register RK_CAT(test_reg_, __LINE__)(name, RK_CAT(test_fn_, __LINE__)); \
  static void RK_CAT(test_fn_, __LINE__)()

#define CHECK(cond)                                         \
  do {                                                      \
    if (!(cond)) rk::fail(__FILE__, __LINE__, #cond);       \
  } while (0)

#define CHECK_EQ(a, b)                                                                   \
  do {                                                                                   \
    const auto rk_a = (a);                                                               \
    const auto rk_b = (b);                                                               \
    if (!(rk_a == rk_b)) rk::fail(__FILE__, __LINE__, std::string(#a " == " #b));        \
  } while (0)

// Passes when [expr] throws an exception of type [type] (or a subclass).
#define CHECK_THROWS(type, expr)                                                          \
  do {                                                                                    \
    bool rk_threw = false;                                                                \
    try {                                                                                 \
      (void)(expr);                                                                       \
    } catch (const type&) {                                                               \
      rk_threw = true;                                                                    \
    } catch (...) {                                                                       \
    }                                                                                     \
    if (!rk_threw) rk::fail(__FILE__, __LINE__, "expected " #type " from " #expr);       \
  } while (0)

#define RK_MAIN(suite) \
  int main() { return rk::run(suite); }
