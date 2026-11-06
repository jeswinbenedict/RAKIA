/* SPDX-License-Identifier: Apache-2.0
 * libFuzzer target: feeds arbitrary bytes (as doubles, strings and config)
 * into every public entry point. Any crash, sanitizer report or hang fails. */
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "rakia/rakia.h"
#include "rakia/rakia_flat.h"

#define MAX_N 256

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size);

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    static double x[MAX_N];
    static double t[MAX_N];
    static double scratch[MAX_N * (MAX_N - 1) / 2];
    static double q[MAX_N];
    static uint32_t flags[MAX_N];
    static double zbuf[MAX_N];
    size_t n = size / sizeof(double);
    if (n > MAX_N) {
        n = MAX_N;
    }
    memcpy(x, data, n * sizeof(double));
    for (size_t i = 0; i < n; ++i) {
        t[i] = (double)i;
    }

    double med = 0.0;
    double mad = 0.0;
    (void)rakia_median_mad(x, n, scratch, &med, &mad);

    rakia_quality_config qc = {-1e6, 1e6, (double)n};
    rakia_quality_summary qs;
    (void)rakia_quality_assess(x, NULL, n, &qc, q, flags, &qs);

    rakia_baseline_config bc;
    rakia_baseline_config_default(&bc);
    bc.min_samples = 3;
    rakia_baseline b;
    if (rakia_baseline_compute(x, q, n, &bc, scratch, &b) == RAKIA_OK) {
        rakia_assess_config ac;
        rakia_assess_config_default(&ac);
        rakia_assessment a;
        (void)rakia_assess(x, q, n, &b, &ac, zbuf, &a);
    }

    rakia_cusum_config cc;
    rakia_cusum_config_default(&cc);
    rakia_cusum_result cr;
    (void)rakia_cusum(x, n, &cc, &cr);

    rakia_trend tr;
    (void)rakia_trend_compute(t, x, n, scratch, sizeof(scratch) / sizeof(scratch[0]), &tr);

    if (n >= 6) {
        const size_t d = 2;
        double corr[4];
        double work[6];
        double d2 = 0.0;
        double contrib[2];
        if (rakia_correlation(x, n / d, d, 0.1, corr) == RAKIA_OK) {
            (void)rakia_mahalanobis(x, corr, d, work, &d2, contrib);
        }
        (void)rakia_mahalanobis(x, x + 2, d, work, &d2, contrib);
    }

    /* Ledger: arbitrary strings for code and unit. */
    char code[80];
    char unit[48];
    const size_t code_len = size < sizeof(code) - 1 ? size : sizeof(code) - 1;
    memcpy(code, data, code_len);
    code[code_len] = '\0';
    const size_t unit_len = size < sizeof(unit) - 1 ? size : sizeof(unit) - 1;
    memcpy(unit, data, unit_len);
    unit[unit_len] = '\0';
    rakia_record rec;
    memset(&rec, 0, sizeof(rec));
    rec.metric_code = code;
    rec.unit = unit;
    rec.value = n > 0 ? x[0] : 0.0;
    rec.method = size > 0 ? data[0] : 1;
    rec.provenance = size > 1 ? data[1] : 1;
    rec.client_seq = 1;
    uint8_t h[RAKIA_HASH_SIZE];
    (void)rakia_record_hash(&rec, h);
    (void)rakia_sha256(data, size, h);

    /* Flat ABI: arbitrary doubles as packed configs and baselines, which
     * exercises the count conversion (NaN, negative, fractional, huge). */
    if (n >= RAKIA_FLAT_AC_LEN + RAKIA_FLAT_B_LEN) {
        double fb[RAKIA_FLAT_B_LEN];
        double fa[RAKIA_FLAT_A_LEN];
        double fs[RAKIA_FLAT_QS_LEN];
        double fz = 0.0;
        (void)rakia_flat_baseline_compute(x, NULL, n, x, scratch, fb);
        (void)rakia_flat_robust_z(x[0], x + RAKIA_FLAT_AC_LEN, &fz);
        (void)rakia_flat_assess(x, NULL, n, x + RAKIA_FLAT_AC_LEN, x, zbuf, fa);
        (void)rakia_flat_quality_assess(x, NULL, n, x[0], x[1], x[2], q, flags, fs);
        (void)rakia_flat_cusum(x, n, x[0], x[1], fa);
    }
    const int64_t ints[RAKIA_FLAT_R_LEN] = {n > 0 ? (int64_t)size : 0,
                                            size > 2 ? (int64_t)data[2] - 1 : 1};
    (void)rakia_flat_record_hash(h, h, code, rec.value, unit, ints, rec.method, rec.provenance,
                                 h, h);
    return 0;
}
