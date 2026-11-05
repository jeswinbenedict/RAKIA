/* SPDX-License-Identifier: Apache-2.0 */
#include <stdlib.h>

#include "rk_test.h"

static double g_scratch[RAKIA_TREND_MAX_N * (RAKIA_TREND_MAX_N - 1) / 2];

static void test_exact_line(void)
{
    double t[20];
    double y[20];
    for (int i = 0; i < 20; ++i) {
        t[i] = (double)i;
        y[i] = 3.0 + 0.25 * (double)i;
    }
    rakia_trend r;
    const size_t need = rakia_trend_scratch_size(20);
    CHECK(need == 190);
    CHECK_STATUS(rakia_trend_compute(t, y, 20, g_scratch, need, &r), RAKIA_OK);
    CHECK_NEAR(r.slope, 0.25, 1e-15);
    CHECK_NEAR(r.intercept, 3.0, 1e-12);
    CHECK_NEAR(r.mk_s, 190.0, 0.0); /* all pairs increasing */
    CHECK(r.p_value < 1e-6);
    CHECK(r.n == 20);
}

static void test_robust_to_outlier(void)
{
    double t[15];
    double y[15];
    for (int i = 0; i < 15; ++i) {
        t[i] = (double)i;
        y[i] = 10.0 - 0.5 * (double)i;
    }
    y[7] = 1000.0;
    rakia_trend r;
    CHECK_STATUS(rakia_trend_compute(t, y, 15, g_scratch, rakia_trend_scratch_size(15), &r),
                 RAKIA_OK);
    CHECK_NEAR(r.slope, -0.5, 1e-12);
    CHECK(r.mk_z < 0.0);
}

static void test_no_trend_with_ties(void)
{
    const double t[] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};
    const double y[] = {5, 5, 5, 5, 5, 5, 5, 5, 5, 5};
    rakia_trend r;
    CHECK_STATUS(rakia_trend_compute(t, y, 10, g_scratch, rakia_trend_scratch_size(10), &r),
                 RAKIA_OK);
    CHECK_NEAR(r.slope, 0.0, 0.0);
    CHECK_NEAR(r.mk_s, 0.0, 0.0);
    CHECK_NEAR(r.p_value, 1.0, 0.0);
}

static void test_known_mann_kendall(void)
{
    /* S = 4 for y = {1, 3, 2, 4}: pairs (+,+,+,-,+,+) -> 5 - 1 = 4.
     * var = 4*3*13/18 = 8.6667, z = (4 - 1)/sqrt(8.6667) = 1.01905. */
    const double t[] = {0, 1, 2, 3};
    const double y[] = {1, 3, 2, 4};
    rakia_trend r;
    CHECK_STATUS(rakia_trend_compute(t, y, 4, g_scratch, rakia_trend_scratch_size(4), &r),
                 RAKIA_OK);
    CHECK_NEAR(r.mk_s, 4.0, 0.0);
    CHECK_NEAR(r.mk_z, 3.0 / sqrt(104.0 / 12.0), 1e-12);
    CHECK_NEAR(r.p_value, 0.30818, 1e-4); /* two-sided normal tail at z = 1.019 */
}

static void test_invalid(void)
{
    const double t[] = {0, 2, 1};
    const double y[] = {1, 2, 3};
    rakia_trend r;
    CHECK_STATUS(rakia_trend_compute(t, y, 3, g_scratch, 3, &r), RAKIA_E_RANGE);
    CHECK_STATUS(rakia_trend_compute(t, y, 2, g_scratch, 3, &r), RAKIA_E_INSUFFICIENT);
    const double t_ok[] = {0, 1, 2, 3};
    const double y_ok[] = {1, 2, 3, 4};
    CHECK_STATUS(rakia_trend_compute(t_ok, y_ok, 4, g_scratch, 5, &r), RAKIA_E_BUFFER);
    const double y_nan[] = {1, NAN, 3, 4};
    CHECK_STATUS(rakia_trend_compute(t_ok, y_nan, 4, g_scratch, 6, &r), RAKIA_E_NONFINITE);
    const double t_same[] = {1, 1, 1, 1};
    CHECK_STATUS(rakia_trend_compute(t_same, y_ok, 4, g_scratch, 6, &r), RAKIA_E_INSUFFICIENT);
    CHECK_STATUS(rakia_trend_compute(t_ok, y_ok, RAKIA_TREND_MAX_N + 1, g_scratch, 1, &r),
                 RAKIA_E_RANGE);
    CHECK_STATUS(rakia_trend_compute(NULL, y_ok, 4, g_scratch, 6, &r), RAKIA_E_NULL);
}

int main(void)
{
    test_exact_line();
    test_robust_to_outlier();
    test_no_trend_with_ties();
    test_known_mann_kendall();
    test_invalid();
    return rk_report("test_trend");
}
