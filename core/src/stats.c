/* SPDX-License-Identifier: Apache-2.0 */
#include <stdlib.h>
#include <string.h>

#include "internal.h"

static int rk_cmp_double(const void *a, const void *b)
{
    const double x = *(const double *)a;
    const double y = *(const double *)b;
    return (x > y) - (x < y);
}

void rk_sort(double *buf, size_t n)
{
    if (n > 1) {
        qsort(buf, n, sizeof(double), rk_cmp_double);
    }
}

double rk_sorted_median(const double *sorted, size_t n)
{
    const size_t mid = n / 2;
    if (n % 2 == 1) {
        return sorted[mid];
    }
    /* Average written as a + (b - a) / 2 to avoid overflow for huge values. */
    return sorted[mid - 1] + (sorted[mid] - sorted[mid - 1]) / 2.0;
}

void rk_median_mad_inplace(double *buf, size_t n, double *median, double *mad_scaled)
{
    rk_sort(buf, n);
    const double med = rk_sorted_median(buf, n);
    for (size_t i = 0; i < n; ++i) {
        buf[i] = fabs(buf[i] - med);
    }
    rk_sort(buf, n);
    *median = med;
    *mad_scaled = rk_sorted_median(buf, n) * RAKIA_MAD_SCALE;
}

static rakia_status rk_copy_finite(const double *x, size_t n, double *scratch)
{
    if (x == NULL || scratch == NULL) {
        return RAKIA_E_NULL;
    }
    if (n == 0) {
        return RAKIA_E_EMPTY;
    }
    if (scratch == x) {
        return RAKIA_E_RANGE; /* scratch must not alias the input */
    }
    for (size_t i = 0; i < n; ++i) {
        if (!rk_finite(x[i])) {
            return RAKIA_E_NONFINITE;
        }
    }
    memcpy(scratch, x, n * sizeof(double));
    return RAKIA_OK;
}

rakia_status rakia_median(const double *x, size_t n, double *scratch, double *out_median)
{
    if (out_median == NULL) {
        return RAKIA_E_NULL;
    }
    const rakia_status st = rk_copy_finite(x, n, scratch);
    if (st != RAKIA_OK) {
        return st;
    }
    rk_sort(scratch, n);
    *out_median = rk_sorted_median(scratch, n);
    return RAKIA_OK;
}

rakia_status rakia_median_mad(const double *x, size_t n, double *scratch, double *out_median,
                              double *out_mad_scaled)
{
    if (out_median == NULL || out_mad_scaled == NULL) {
        return RAKIA_E_NULL;
    }
    const rakia_status st = rk_copy_finite(x, n, scratch);
    if (st != RAKIA_OK) {
        return st;
    }
    rk_median_mad_inplace(scratch, n, out_median, out_mad_scaled);
    return RAKIA_OK;
}
