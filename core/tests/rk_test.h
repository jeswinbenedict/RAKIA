/* SPDX-License-Identifier: Apache-2.0
 * Minimal dependency-free test harness and deterministic RNG for librakia. */
#ifndef RK_TEST_H
#define RK_TEST_H

#include <math.h>
#include <stdint.h>
#include <stdio.h>

#include "rakia/rakia.h"

static int rk_failures = 0;
static int rk_checks = 0;

#define CHECK(cond)                                                                            \
    do {                                                                                       \
        ++rk_checks;                                                                           \
        if (!(cond)) {                                                                         \
            fprintf(stderr, "%s:%d: CHECK failed: %s\n", __FILE__, __LINE__, #cond);           \
            ++rk_failures;                                                                     \
        }                                                                                      \
    } while (0)

#define CHECK_NEAR(a, b, tol)                                                                  \
    do {                                                                                       \
        ++rk_checks;                                                                           \
        const double rk_a_ = (a);                                                              \
        const double rk_b_ = (b);                                                              \
        if (!(fabs(rk_a_ - rk_b_) <= (tol))) {                                                 \
            fprintf(stderr, "%s:%d: CHECK_NEAR failed: %s = %.17g, expected %.17g (tol %g)\n", \
                    __FILE__, __LINE__, #a, rk_a_, rk_b_, (double)(tol));                      \
            ++rk_failures;                                                                     \
        }                                                                                      \
    } while (0)

#define CHECK_STATUS(expr, expected)                                                           \
    do {                                                                                       \
        ++rk_checks;                                                                           \
        const rakia_status rk_s_ = (expr);                                                     \
        if (rk_s_ != (expected)) {                                                             \
            fprintf(stderr, "%s:%d: %s returned %d (%s), expected %d\n", __FILE__, __LINE__,   \
                    #expr, (int)rk_s_, rakia_status_str(rk_s_), (int)(expected));              \
            ++rk_failures;                                                                     \
        }                                                                                      \
    } while (0)

static inline int rk_report(const char *name)
{
    printf("%s: %d checks, %d failures\n", name, rk_checks, rk_failures);
    return rk_failures == 0 ? 0 : 1;
}

/* splitmix64: small, fast, fully deterministic across platforms. */
typedef struct rk_rng {
    uint64_t state;
} rk_rng;

static inline uint64_t rk_rng_next(rk_rng *r)
{
    uint64_t z = (r->state += 0x9E3779B97F4A7C15ull);
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ull;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBull;
    return z ^ (z >> 31);
}

/* Uniform in (0, 1). */
static inline double rk_rng_uniform(rk_rng *r)
{
    return ((double)(rk_rng_next(r) >> 11) + 0.5) * (1.0 / 9007199254740992.0);
}

/* Approximately standard normal via Irwin-Hall (sum of 12 uniforms - 6).
 * Uses only IEEE 754 addition, so generated data is bit-identical on every
 * platform; the tails are truncated at +/-6 SD. */
static inline double rk_rng_normal(rk_rng *r)
{
    double s = 0.0;
    for (int i = 0; i < 12; ++i) {
        s += rk_rng_uniform(r);
    }
    return s - 6.0;
}

#endif /* RK_TEST_H */
