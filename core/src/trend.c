/* SPDX-License-Identifier: Apache-2.0 */
#include "internal.h"

size_t rakia_trend_scratch_size(size_t n)
{
    if (n < 2) {
        return n;
    }
    const size_t pairs = n * (n - 1) / 2;
    return (pairs > n) ? pairs : n;
}

static double rk_sign(double d) { return (double)((d > 0.0) - (d < 0.0)); }

rakia_status rakia_trend_compute(const double *t, const double *y, size_t n, double *scratch,
                                 size_t scratch_len, rakia_trend *out)
{
    if (t == NULL || y == NULL || scratch == NULL || out == NULL) {
        return RAKIA_E_NULL;
    }
    if (n == 0) {
        return RAKIA_E_EMPTY;
    }
    if (n < 3) {
        return RAKIA_E_INSUFFICIENT;
    }
    if (n > RAKIA_TREND_MAX_N) {
        return RAKIA_E_RANGE;
    }
    if (scratch_len < rakia_trend_scratch_size(n)) {
        return RAKIA_E_BUFFER;
    }
    for (size_t i = 0; i < n; ++i) {
        if (!rk_finite(t[i]) || !rk_finite(y[i])) {
            return RAKIA_E_NONFINITE;
        }
        if (i > 0 && t[i] < t[i - 1]) {
            return RAKIA_E_RANGE; /* time must be non-decreasing */
        }
    }

    /* Theil-Sen: median of pairwise slopes; Mann-Kendall S in the same pass. */
    size_t m = 0;
    double s = 0.0;
    for (size_t i = 0; i + 1 < n; ++i) {
        for (size_t j = i + 1; j < n; ++j) {
            s += rk_sign(y[j] - y[i]);
            const double dt = t[j] - t[i];
            if (dt > 0.0) {
                scratch[m++] = (y[j] - y[i]) / dt;
            }
        }
    }
    if (m == 0) {
        return RAKIA_E_INSUFFICIENT; /* every t was identical */
    }
    rk_sort(scratch, m);
    const double slope = rk_sorted_median(scratch, m);
    if (!rk_finite(slope)) {
        return RAKIA_E_NONFINITE;
    }

    for (size_t i = 0; i < n; ++i) {
        scratch[i] = y[i] - slope * t[i];
    }
    rk_sort(scratch, n);
    const double intercept = rk_sorted_median(scratch, n);

    /* Variance of S with correction for tied y values. */
    for (size_t i = 0; i < n; ++i) {
        scratch[i] = y[i];
    }
    rk_sort(scratch, n);
    const double nd = (double)n;
    double var = nd * (nd - 1.0) * (2.0 * nd + 5.0);
    size_t i = 0;
    while (i < n) {
        size_t j = i + 1;
        while (j < n && scratch[j] == scratch[i]) {
            ++j;
        }
        const double g = (double)(j - i);
        if (g > 1.0) {
            var -= g * (g - 1.0) * (2.0 * g + 5.0);
        }
        i = j;
    }
    var /= 18.0;

    double zscore = 0.0;
    double p = 1.0;
    if (var > 0.0) {
        const double sd = sqrt(var);
        if (s > 0.0) {
            zscore = (s - 1.0) / sd;
        } else if (s < 0.0) {
            zscore = (s + 1.0) / sd;
        }
        p = erfc(fabs(zscore) / sqrt(2.0));
    }

    out->slope = slope;
    out->intercept = intercept;
    out->mk_s = s;
    out->mk_z = zscore;
    out->p_value = (p > 1.0) ? 1.0 : p;
    out->n = n;
    return RAKIA_OK;
}
