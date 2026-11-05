/* SPDX-License-Identifier: Apache-2.0 */
#include "internal.h"

static int rk_row_complete(const double *row, size_t d)
{
    for (size_t j = 0; j < d; ++j) {
        if (!rk_finite(row[j])) {
            return 0;
        }
    }
    return 1;
}

rakia_status rakia_correlation(const double *x, size_t n, size_t d, double shrinkage,
                               double *corr_out)
{
    if (x == NULL || corr_out == NULL) {
        return RAKIA_E_NULL;
    }
    if (n == 0 || d == 0) {
        return RAKIA_E_EMPTY;
    }
    if (!rk_finite(shrinkage)) {
        return RAKIA_E_NONFINITE;
    }
    if (d > RAKIA_MV_MAX_D || shrinkage < 0.0 || shrinkage > 1.0) {
        return RAKIA_E_RANGE;
    }

    double mean[RAKIA_MV_MAX_D];
    for (size_t j = 0; j < d; ++j) {
        mean[j] = 0.0;
    }
    size_t rows = 0;
    for (size_t r = 0; r < n; ++r) {
        const double *row = x + r * d;
        if (!rk_row_complete(row, d)) {
            continue;
        }
        ++rows;
        for (size_t j = 0; j < d; ++j) {
            mean[j] += row[j];
        }
    }
    if (rows < d + 2) {
        return RAKIA_E_INSUFFICIENT;
    }
    for (size_t j = 0; j < d; ++j) {
        mean[j] /= (double)rows;
    }

    /* Covariance (unnormalised) into corr_out. */
    for (size_t a = 0; a < d * d; ++a) {
        corr_out[a] = 0.0;
    }
    for (size_t r = 0; r < n; ++r) {
        const double *row = x + r * d;
        if (!rk_row_complete(row, d)) {
            continue;
        }
        for (size_t a = 0; a < d; ++a) {
            const double da = row[a] - mean[a];
            for (size_t b = a; b < d; ++b) {
                corr_out[a * d + b] += da * (row[b] - mean[b]);
            }
        }
    }

    double sd[RAKIA_MV_MAX_D];
    for (size_t a = 0; a < d; ++a) {
        const double v = corr_out[a * d + a];
        if (!(v > 0.0)) {
            return RAKIA_E_DEGENERATE; /* a feature is constant */
        }
        sd[a] = sqrt(v);
    }
    for (size_t a = 0; a < d; ++a) {
        for (size_t b = a; b < d; ++b) {
            double r = (a == b) ? 1.0 : corr_out[a * d + b] / (sd[a] * sd[b]);
            if (r > 1.0) {
                r = 1.0;
            } else if (r < -1.0) {
                r = -1.0;
            }
            const double shrunk =
                (1.0 - shrinkage) * r + ((a == b) ? shrinkage : 0.0);
            corr_out[a * d + b] = shrunk;
            corr_out[b * d + a] = shrunk;
        }
    }
    return RAKIA_OK;
}

rakia_status rakia_mahalanobis(const double *z, const double *corr, size_t d, double *work,
                               double *d2_out, double *contrib_out)
{
    if (z == NULL || corr == NULL || work == NULL || d2_out == NULL) {
        return RAKIA_E_NULL;
    }
    if (d == 0) {
        return RAKIA_E_EMPTY;
    }
    if (d > RAKIA_MV_MAX_D) {
        return RAKIA_E_RANGE;
    }
    for (size_t i = 0; i < d; ++i) {
        if (!rk_finite(z[i])) {
            return RAKIA_E_NONFINITE;
        }
    }
    for (size_t a = 0; a < d * d; ++a) {
        if (!rk_finite(corr[a])) {
            return RAKIA_E_NONFINITE;
        }
    }
    for (size_t a = 0; a < d; ++a) {
        for (size_t b = a + 1; b < d; ++b) {
            const double u = corr[a * d + b];
            const double v = corr[b * d + a];
            const double scale = fabs(u) > 1.0 ? fabs(u) : 1.0;
            if (fabs(u - v) > 1e-9 * scale) {
                return RAKIA_E_SINGULAR; /* not symmetric */
            }
        }
    }

    /* Cholesky: corr = L L^T, L stored in the lower triangle of work. */
    double *l = work;
    double *w = work + d * d;
    for (size_t a = 0; a < d * d; ++a) {
        l[a] = 0.0;
    }
    for (size_t i = 0; i < d; ++i) {
        for (size_t j = 0; j <= i; ++j) {
            double sum = corr[i * d + j];
            for (size_t k = 0; k < j; ++k) {
                sum -= l[i * d + k] * l[j * d + k];
            }
            if (i == j) {
                if (!(sum > 1e-12)) {
                    return RAKIA_E_SINGULAR;
                }
                l[i * d + i] = sqrt(sum);
            } else {
                l[i * d + j] = sum / l[j * d + j];
            }
        }
    }

    /* Forward solve L y = z (y in w), then back solve L^T w = y. */
    for (size_t i = 0; i < d; ++i) {
        double sum = z[i];
        for (size_t k = 0; k < i; ++k) {
            sum -= l[i * d + k] * w[k];
        }
        w[i] = sum / l[i * d + i];
    }
    for (size_t ii = d; ii-- > 0;) {
        double sum = w[ii];
        for (size_t k = ii + 1; k < d; ++k) {
            sum -= l[k * d + ii] * w[k];
        }
        w[ii] = sum / l[ii * d + ii];
    }

    double d2 = 0.0;
    for (size_t i = 0; i < d; ++i) {
        const double c = z[i] * w[i];
        d2 += c;
        if (contrib_out != NULL) {
            contrib_out[i] = c;
        }
    }
    *d2_out = d2;
    return RAKIA_OK;
}
