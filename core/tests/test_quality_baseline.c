/* SPDX-License-Identifier: Apache-2.0 */
#include "rk_test.h"

static void test_quality(void)
{
    const double v[] = {60.0, NAN, 300.0, 62.0, 61.0, 10.0};
    const uint32_t sensor[] = {0, 0, 0, 1, 0, 0};
    double q[6];
    uint32_t f[6];
    rakia_quality_summary s;
    const rakia_quality_config cfg = {25.0, 220.0, 12.0};
    CHECK_STATUS(rakia_quality_assess(v, sensor, 6, &cfg, q, f, &s), RAKIA_OK);
    CHECK(q[0] == 1.0 && q[4] == 1.0);
    CHECK(q[1] == 0.0 && f[1] == RAKIA_QF_NONFINITE);
    CHECK(q[2] == 0.0 && f[2] == RAKIA_QF_IMPLAUSIBLE);
    CHECK(q[3] == 0.0 && f[3] == RAKIA_QF_SENSOR);
    CHECK(q[5] == 0.0 && f[5] == RAKIA_QF_IMPLAUSIBLE);
    CHECK(s.n_total == 6 && s.n_valid == 2);
    CHECK_NEAR(s.fraction_valid, 2.0 / 6.0, 1e-15);
    CHECK_NEAR(s.completeness, 2.0 / 12.0, 1e-15);
    CHECK_NEAR(s.score, (2.0 / 6.0) * (2.0 / 12.0), 1e-15);

    /* Completeness caps at 1 and can be disabled. */
    const rakia_quality_config nocomp = {25.0, 220.0, 0.0};
    CHECK_STATUS(rakia_quality_assess(v, NULL, 1, &nocomp, q, NULL, &s), RAKIA_OK);
    CHECK_NEAR(s.completeness, 1.0, 0.0);

    const rakia_quality_config bad = {220.0, 25.0, 0.0};
    CHECK_STATUS(rakia_quality_assess(v, NULL, 6, &bad, q, f, &s), RAKIA_E_RANGE);
    CHECK_STATUS(rakia_quality_assess(v, NULL, 0, &cfg, q, f, &s), RAKIA_E_EMPTY);
    CHECK_STATUS(rakia_quality_assess(v, NULL, 6, &cfg, NULL, f, &s), RAKIA_E_NULL);
}

static void test_baseline(void)
{
    double v[20];
    double q[20];
    for (int i = 0; i < 20; ++i) {
        v[i] = 60.0 + (double)(i % 5); /* 60..64 repeating, median 62 */
        q[i] = 1.0;
    }
    v[3] = 500.0; /* outlier: robust statistics must ignore it */
    v[7] = NAN;   /* always excluded */
    q[9] = 0.0;   /* excluded by quality */
    double scratch[20];
    rakia_baseline_config cfg;
    rakia_baseline_config_default(&cfg);
    CHECK(cfg.min_samples == 14);
    rakia_baseline b;
    CHECK_STATUS(rakia_baseline_compute(v, q, 20, &cfg, scratch, &b), RAKIA_OK);
    CHECK(b.n == 18);
    CHECK_NEAR(b.center, 62.0, 0.0);
    CHECK(b.spread > 0.5 && b.spread < 3.0);

    /* Insufficient data. */
    cfg.min_samples = 19;
    CHECK_STATUS(rakia_baseline_compute(v, q, 20, &cfg, scratch, &b), RAKIA_E_INSUFFICIENT);

    /* Spread floor for quantised constant data. */
    double flat[15];
    for (int i = 0; i < 15; ++i) {
        flat[i] = 70.0;
    }
    rakia_baseline_config_default(&cfg);
    cfg.min_spread = 2.0;
    CHECK_STATUS(rakia_baseline_compute(flat, NULL, 15, &cfg, scratch, &b), RAKIA_OK);
    CHECK_NEAR(b.spread, 2.0, 0.0);

    double z = 0.0;
    CHECK_STATUS(rakia_robust_z(74.0, &b, &z), RAKIA_OK);
    CHECK_NEAR(z, 2.0, 1e-15);
    rakia_baseline zero = {70.0, 0.0, 15};
    CHECK_STATUS(rakia_robust_z(74.0, &zero, &z), RAKIA_E_DEGENERATE);
    CHECK_STATUS(rakia_robust_z(NAN, &b, &z), RAKIA_E_NONFINITE);

    cfg.min_spread = 0.0;
    CHECK_STATUS(rakia_baseline_compute(flat, NULL, 15, &cfg, scratch, &b), RAKIA_E_RANGE);
    rakia_baseline_config_default(&cfg);
    cfg.min_samples = 2;
    CHECK_STATUS(rakia_baseline_compute(flat, NULL, 15, &cfg, scratch, &b), RAKIA_E_RANGE);
    rakia_baseline_config_default(&cfg);
    CHECK_STATUS(rakia_baseline_compute(flat, NULL, 15, &cfg, flat, &b), RAKIA_E_RANGE);
}

int main(void)
{
    test_quality();
    test_baseline();
    return rk_report("test_quality_baseline");
}
