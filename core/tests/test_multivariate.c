/* SPDX-License-Identifier: Apache-2.0 */
#include "rk_test.h"

static void test_identity(void)
{
    const double z[3] = {1.0, -2.0, 0.5};
    const double eye[9] = {1, 0, 0, 0, 1, 0, 0, 0, 1};
    double work[12];
    double d2 = 0.0;
    double c[3];
    CHECK_STATUS(rakia_mahalanobis(z, eye, 3, work, &d2, c), RAKIA_OK);
    CHECK_NEAR(d2, 5.25, 1e-14);
    CHECK_NEAR(c[0], 1.0, 1e-14);
    CHECK_NEAR(c[1], 4.0, 1e-14);
    CHECK_NEAR(c[2], 0.25, 1e-14);
}

static void test_correlated_2d(void)
{
    /* R = [[1, r], [r, 1]]: D^2 = (z1^2 - 2 r z1 z2 + z2^2) / (1 - r^2). */
    const double r = 0.6;
    const double corr[4] = {1.0, r, r, 1.0};
    const double z[2] = {2.0, 2.0};
    double work[6];
    double d2 = 0.0;
    double c[2];
    CHECK_STATUS(rakia_mahalanobis(z, corr, 2, work, &d2, c), RAKIA_OK);
    const double expected = (4.0 - 2.0 * r * 4.0 + 4.0) / (1.0 - r * r);
    CHECK_NEAR(d2, expected, 1e-12);
    CHECK_NEAR(c[0] + c[1], d2, 1e-12);

    /* Opposite deviations on positively correlated features are unusual. */
    const double z2[2] = {2.0, -2.0};
    double d2b = 0.0;
    CHECK_STATUS(rakia_mahalanobis(z2, corr, 2, work, &d2b, NULL), RAKIA_OK);
    CHECK(d2b > d2);
}

static void test_singular_and_invalid(void)
{
    const double z[2] = {1.0, 1.0};
    const double singular[4] = {1.0, 1.0, 1.0, 1.0};
    const double asym[4] = {1.0, 0.5, 0.2, 1.0};
    double work[6];
    double d2 = 0.0;
    CHECK_STATUS(rakia_mahalanobis(z, singular, 2, work, &d2, NULL), RAKIA_E_SINGULAR);
    CHECK_STATUS(rakia_mahalanobis(z, asym, 2, work, &d2, NULL), RAKIA_E_SINGULAR);
    const double znan[2] = {1.0, NAN};
    const double eye[4] = {1, 0, 0, 1};
    CHECK_STATUS(rakia_mahalanobis(znan, eye, 2, work, &d2, NULL), RAKIA_E_NONFINITE);
    CHECK_STATUS(rakia_mahalanobis(z, eye, 0, work, &d2, NULL), RAKIA_E_EMPTY);
    CHECK_STATUS(rakia_mahalanobis(z, eye, RAKIA_MV_MAX_D + 1, work, &d2, NULL), RAKIA_E_RANGE);
    CHECK_STATUS(rakia_mahalanobis(z, eye, 2, NULL, &d2, NULL), RAKIA_E_NULL);
}

static void test_correlation(void)
{
    /* Feature b = 2a + 1 (perfect correlation), c alternates (uncorrelated). */
    double x[8 * 3];
    for (int i = 0; i < 8; ++i) {
        x[i * 3 + 0] = (double)i;
        x[i * 3 + 1] = 2.0 * (double)i + 1.0;
        x[i * 3 + 2] = (i % 2 == 0) ? 1.0 : -1.0;
    }
    x[2 * 3 + 1] = NAN; /* incomplete row is skipped */
    double r[9];
    CHECK_STATUS(rakia_correlation(x, 8, 3, 0.0, r), RAKIA_OK);
    CHECK_NEAR(r[0], 1.0, 1e-12);
    CHECK_NEAR(r[1], 1.0, 1e-12);
    CHECK_NEAR(r[3], r[1], 0.0);

    /* Shrinkage makes the perfectly correlated pair invertible. */
    CHECK_STATUS(rakia_correlation(x, 8, 3, 0.2, r), RAKIA_OK);
    CHECK_NEAR(r[1], 0.8, 1e-12);
    CHECK_NEAR(r[4], 1.0, 1e-12);
    double work[12];
    double d2 = 0.0;
    const double z[3] = {1.0, 1.0, 0.0};
    CHECK_STATUS(rakia_mahalanobis(z, r, 3, work, &d2, NULL), RAKIA_OK);

    CHECK_STATUS(rakia_correlation(x, 4, 3, 0.1, r), RAKIA_E_INSUFFICIENT);
    CHECK_STATUS(rakia_correlation(x, 8, 3, 1.5, r), RAKIA_E_RANGE);
    double flat[6 * 2];
    for (int i = 0; i < 6; ++i) {
        flat[i * 2] = (double)i;
        flat[i * 2 + 1] = 4.0;
    }
    CHECK_STATUS(rakia_correlation(flat, 6, 2, 0.1, r), RAKIA_E_DEGENERATE);
}

int main(void)
{
    test_identity();
    test_correlated_2d();
    test_singular_and_invalid();
    test_correlation();
    return rk_report("test_multivariate");
}
