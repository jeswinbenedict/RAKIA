/* SPDX-License-Identifier: Apache-2.0
 *
 * Synthetic validation of the baseline + assessment pipeline.
 * These are ENGINEERING metrics on simulated data with known ground truth.
 * They are not clinical sensitivity/specificity.
 *
 * Each run: 60-sample reference window -> robust baseline; then a 60-sample
 * monitoring window. Scenarios: no change, +1.5 SD step at sample 30, and a
 * linear drift reaching +3 SD at the last sample. Values are N(60, 2^2) in
 * "bpm"-like units.
 *
 * The run also computes a SHA-256 digest of every output so CI can prove the
 * engine is bit-identical across compilers and platforms.
 */
#include <stdlib.h>
#include <string.h>

#include "rk_test.h"

#ifndef RK_GOLDEN_DIGEST
#define RK_GOLDEN_DIGEST "ba385f8cf40a97910b2c3a0a918936908a119014fb87b2269c7f4ccc733b18bc"
#endif

#define RUNS 2000
#define REF_N 60
#define MON_N 60
#define CHANGE_AT 30
#define MU 60.0
#define SIGMA 2.0

enum scenario { SC_NULL = 0, SC_STEP = 1, SC_DRIFT = 2 };

typedef struct metrics {
    int alarms;
    int acts;
    int watch_or_act;
    int detections;
    int delays[RUNS];
    int onset_err[RUNS];
} metrics;

#define DIGEST_BYTES_PER_RUN (5 * sizeof(double) + 4 * sizeof(uint32_t))
static uint8_t g_digest_buf[RUNS * 3 * DIGEST_BYTES_PER_RUN];
static size_t g_digest_len = 0;

static void digest_append(const void *p, size_t n)
{
    memcpy(g_digest_buf + g_digest_len, p, n);
    g_digest_len += n;
}

static int cmp_int(const void *a, const void *b)
{
    const int x = *(const int *)a;
    const int y = *(const int *)b;
    return (x > y) - (x < y);
}

static int median_int(int *v, int n)
{
    if (n == 0) {
        return -1;
    }
    qsort(v, (size_t)n, sizeof(int), cmp_int);
    return v[n / 2];
}

static void run_scenario(enum scenario sc, rk_rng *rng, metrics *m)
{
    memset(m, 0, sizeof(*m));
    double ref[REF_N];
    double mon[MON_N];
    double scratch[REF_N];
    double z[MON_N];
    rakia_baseline_config bcfg;
    rakia_baseline_config_default(&bcfg);
    bcfg.min_spread = 0.5;
    rakia_assess_config acfg;
    rakia_assess_config_default(&acfg);
    int detected = 0;

    for (int r = 0; r < RUNS; ++r) {
        for (int i = 0; i < REF_N; ++i) {
            ref[i] = MU + SIGMA * rk_rng_normal(rng);
        }
        for (int i = 0; i < MON_N; ++i) {
            double shift = 0.0;
            if (sc == SC_STEP && i >= CHANGE_AT) {
                shift = 1.5 * SIGMA;
            } else if (sc == SC_DRIFT) {
                shift = 3.0 * SIGMA * (double)i / (double)(MON_N - 1);
            }
            mon[i] = MU + shift + SIGMA * rk_rng_normal(rng);
        }
        rakia_baseline b;
        CHECK_STATUS(rakia_baseline_compute(ref, NULL, REF_N, &bcfg, scratch, &b), RAKIA_OK);
        rakia_assessment a;
        CHECK_STATUS(rakia_assess(mon, NULL, MON_N, &b, &acfg, z, &a), RAKIA_OK);

        digest_append(&b.center, sizeof(double));
        digest_append(&b.spread, sizeof(double));
        digest_append(&a.latest_z, sizeof(double));
        digest_append(&a.cusum.s_pos, sizeof(double));
        digest_append(&a.cusum.s_neg, sizeof(double));
        const uint32_t ints[4] = {(uint32_t)a.level, a.reasons, (uint32_t)a.cusum.alarm_index,
                                  (uint32_t)a.cusum.onset_index};
        digest_append(ints, sizeof(ints));

        if (a.cusum.alarm) {
            ++m->alarms;
        }
        if (a.level == RAKIA_LEVEL_ACT) {
            ++m->acts;
        }
        if (a.level >= RAKIA_LEVEL_WATCH) {
            ++m->watch_or_act;
        }
        if (sc == SC_STEP && a.cusum.alarm && a.cusum.direction == 1 &&
            (int)a.cusum.alarm_index >= CHANGE_AT) {
            m->delays[detected] = (int)a.cusum.alarm_index - CHANGE_AT;
            m->onset_err[detected] = abs((int)a.cusum.onset_index - CHANGE_AT);
            ++detected;
        }
    }
    m->detections = detected;
}

int main(void)
{
    rk_rng rng = {UINT64_C(0x52414B4941)}; /* "RAKIA" */
    metrics *m = (metrics *)calloc(1, sizeof(metrics));
    if (m == NULL) {
        fprintf(stderr, "out of memory\n");
        return 1;
    }

    run_scenario(SC_NULL, &rng, m);
    const double null_alarm = (double)m->alarms / RUNS;
    const double null_act = (double)m->acts / RUNS;
    const double null_flag = (double)m->watch_or_act / RUNS;
    printf("no change : CUSUM alarm %.3f | ACT %.3f | WATCH-or-ACT at window end %.3f\n",
           null_alarm, null_act, null_flag);

    run_scenario(SC_STEP, &rng, m);
    const int det = m->detections;
    const double step_det = (double)det / RUNS;
    const int med_delay = median_int(m->delays, det);
    const int med_onset = median_int(m->onset_err, det);
    const double step_act = (double)m->acts / RUNS;
    printf("+1.5 SD step: detected after change %.3f | median delay %d | median onset error %d | "
           "ACT %.3f\n",
           step_det, med_delay, med_onset, step_act);

    run_scenario(SC_DRIFT, &rng, m);
    const double drift_alarm = (double)m->alarms / RUNS;
    const double drift_act = (double)m->acts / RUNS;
    printf("drift to +3 SD: CUSUM alarm %.3f | ACT %.3f\n", drift_alarm, drift_act);

    /* Regression guards (set below the observed values on purpose). */
    /* Observed on this seed: 0.085, 0.017, 0.972, 7, 1, 0.983, 1.000. */
    CHECK(null_flag < 0.12);
    CHECK(null_act < 0.03);
    CHECK(step_det > 0.95);
    CHECK(med_delay >= 0 && med_delay <= 9);
    CHECK(med_onset >= 0 && med_onset <= 2);
    CHECK(step_act > 0.95);
    CHECK(drift_alarm > 0.98);
    CHECK(drift_act > 0.95);

    uint8_t h[RAKIA_HASH_SIZE];
    CHECK_STATUS(rakia_sha256(g_digest_buf, g_digest_len, h), RAKIA_OK);
    char hex[2 * RAKIA_HASH_SIZE + 1];
    static const char digits[] = "0123456789abcdef";
    for (size_t i = 0; i < RAKIA_HASH_SIZE; ++i) {
        hex[2 * i] = digits[h[i] >> 4];
        hex[2 * i + 1] = digits[h[i] & 0x0F];
    }
    hex[2 * RAKIA_HASH_SIZE] = '\0';
    printf("determinism digest: %s\n", hex);
    /* Golden digest: identical on MSVC/x64, GCC and Clang (verified in CI). */
    CHECK(strcmp(hex, RK_GOLDEN_DIGEST) == 0);

    free(m);
    return rk_report("test_validation");
}
