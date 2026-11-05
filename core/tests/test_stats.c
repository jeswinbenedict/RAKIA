/* SPDX-License-Identifier: Apache-2.0 */
#include <string.h>

#include "rk_test.h"

static void test_version_and_status(void)
{
    CHECK(strcmp(rakia_version(), "0.1.0") == 0);
    CHECK(strcmp(rakia_status_str(RAKIA_OK), "ok") == 0);
    CHECK(strcmp(rakia_status_str((rakia_status)999), "unknown status") == 0);
}

static void test_median(void)
{
    double scratch[8];
    double med = 0.0;
    const double odd[] = {5.0, 1.0, 3.0};
    CHECK_STATUS(rakia_median(odd, 3, scratch, &med), RAKIA_OK);
    CHECK_NEAR(med, 3.0, 0.0);

    const double even[] = {4.0, 1.0, 3.0, 2.0};
    CHECK_STATUS(rakia_median(even, 4, scratch, &med), RAKIA_OK);
    CHECK_NEAR(med, 2.5, 0.0);

    const double one[] = {-7.25};
    CHECK_STATUS(rakia_median(one, 1, scratch, &med), RAKIA_OK);
    CHECK_NEAR(med, -7.25, 0.0);

    /* Input must not be modified. */
    CHECK(odd[0] == 5.0 && odd[1] == 1.0 && odd[2] == 3.0);
}

static void test_median_mad(void)
{
    double scratch[16];
    double med = 0.0;
    double mad = 0.0;
    /* Classic example: median 2, |dev| = {1,1,0,0,2,4,7} -> MAD 1. */
    const double x[] = {1.0, 1.0, 2.0, 2.0, 4.0, 6.0, 9.0};
    CHECK_STATUS(rakia_median_mad(x, 7, scratch, &med, &mad), RAKIA_OK);
    CHECK_NEAR(med, 2.0, 0.0);
    CHECK_NEAR(mad, RAKIA_MAD_SCALE, 1e-15);

    const double constant[] = {3.0, 3.0, 3.0, 3.0};
    CHECK_STATUS(rakia_median_mad(constant, 4, scratch, &med, &mad), RAKIA_OK);
    CHECK_NEAR(mad, 0.0, 0.0);
}

static void test_invalid_inputs(void)
{
    double scratch[4];
    double med = 0.0;
    double mad = 0.0;
    const double x[] = {1.0, NAN, 3.0};
    const double inf[] = {1.0, INFINITY};
    CHECK_STATUS(rakia_median(x, 3, scratch, &med), RAKIA_E_NONFINITE);
    CHECK_STATUS(rakia_median(inf, 2, scratch, &med), RAKIA_E_NONFINITE);
    CHECK_STATUS(rakia_median(x, 0, scratch, &med), RAKIA_E_EMPTY);
    CHECK_STATUS(rakia_median(NULL, 3, scratch, &med), RAKIA_E_NULL);
    CHECK_STATUS(rakia_median(x, 3, NULL, &med), RAKIA_E_NULL);
    CHECK_STATUS(rakia_median(x, 3, scratch, NULL), RAKIA_E_NULL);
    CHECK_STATUS(rakia_median_mad(x, 3, scratch, &med, NULL), RAKIA_E_NULL);
    double alias[] = {1.0, 2.0};
    CHECK_STATUS(rakia_median_mad(alias, 2, alias, &med, &mad), RAKIA_E_RANGE);
}

int main(void)
{
    test_version_and_status();
    test_median();
    test_median_mad();
    test_invalid_inputs();
    return rk_report("test_stats");
}
