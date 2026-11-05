/* SPDX-License-Identifier: Apache-2.0 */
#include "rk_test.h"

static void test_no_change(void)
{
    double z[50];
    for (int i = 0; i < 50; ++i) {
        z[i] = (i % 2 == 0) ? 0.4 : -0.4;
    }
    rakia_cusum_config cfg;
    rakia_cusum_config_default(&cfg);
    rakia_cusum_result r;
    CHECK_STATUS(rakia_cusum(z, 50, &cfg, &r), RAKIA_OK);
    CHECK(r.alarm == 0 && r.direction == 0);
    CHECK(r.n_used == 50);
}

static void test_step_up_exact(void)
{
    /* Zeros then a +2 SD step at index 10. With k = 0.5 the upper statistic
     * grows by 1.5 per sample: 1.5, 3.0, 4.5, 6.0 -> crosses h = 5 at 13.
     * (h is set explicitly so the arithmetic is independent of defaults.) */
    double z[30];
    for (int i = 0; i < 30; ++i) {
        z[i] = (i < 10) ? 0.0 : 2.0;
    }
    rakia_cusum_config cfg;
    rakia_cusum_config_default(&cfg);
    CHECK_NEAR(cfg.h, 8.0, 0.0);
    cfg.h = 5.0;
    rakia_cusum_result r;
    CHECK_STATUS(rakia_cusum(z, 30, &cfg, &r), RAKIA_OK);
    CHECK(r.alarm == 1);
    CHECK(r.direction == 1);
    CHECK(r.alarm_index == 13);
    CHECK(r.onset_index == 10);
    CHECK_NEAR(r.s_pos, 6.0, 1e-12);
}

static void test_step_down_with_missing(void)
{
    double z[30];
    for (int i = 0; i < 30; ++i) {
        z[i] = (i < 12) ? 0.1 : -3.0;
    }
    z[13] = NAN; /* missing samples are skipped */
    z[14] = INFINITY;
    rakia_cusum_config cfg;
    rakia_cusum_config_default(&cfg);
    cfg.h = 5.0;
    rakia_cusum_result r;
    CHECK_STATUS(rakia_cusum(z, 30, &cfg, &r), RAKIA_OK);
    CHECK(r.alarm == 1 && r.direction == -1);
    CHECK(r.onset_index == 12);
    /* -3 per sample, k 0.5 -> 2.5, (skip, skip), 5.0, 7.5 -> alarm at 16. */
    CHECK(r.alarm_index == 16);
}

static void test_invalid(void)
{
    double z[3] = {NAN, NAN, NAN};
    rakia_cusum_config cfg;
    rakia_cusum_config_default(&cfg);
    rakia_cusum_result r;
    CHECK_STATUS(rakia_cusum(z, 3, &cfg, &r), RAKIA_E_INSUFFICIENT);
    CHECK_STATUS(rakia_cusum(z, 0, &cfg, &r), RAKIA_E_EMPTY);
    CHECK_STATUS(rakia_cusum(NULL, 3, &cfg, &r), RAKIA_E_NULL);
    cfg.h = 0.0;
    CHECK_STATUS(rakia_cusum(z, 3, &cfg, &r), RAKIA_E_RANGE);
    cfg.h = 5.0;
    cfg.k = -1.0;
    CHECK_STATUS(rakia_cusum(z, 3, &cfg, &r), RAKIA_E_RANGE);
    cfg.k = NAN;
    CHECK_STATUS(rakia_cusum(z, 3, &cfg, &r), RAKIA_E_NONFINITE);
}

int main(void)
{
    test_no_change();
    test_step_up_exact();
    test_step_down_with_missing();
    test_invalid();
    return rk_report("test_cusum");
}
