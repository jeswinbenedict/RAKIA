/* SPDX-License-Identifier: Apache-2.0 */
#include "internal.h"

void rakia_baseline_config_default(rakia_baseline_config *cfg)
{
    if (cfg == NULL) {
        return;
    }
    cfg->min_samples = 14;
    cfg->min_quality = 0.5;
    cfg->min_spread = 1e-6;
}

rakia_status rakia_baseline_compute(const double *values, const double *quality, size_t n,
                                    const rakia_baseline_config *cfg, double *scratch,
                                    rakia_baseline *out)
{
    if (values == NULL || cfg == NULL || scratch == NULL || out == NULL) {
        return RAKIA_E_NULL;
    }
    if (n == 0) {
        return RAKIA_E_EMPTY;
    }
    if (scratch == values) {
        return RAKIA_E_RANGE;
    }
    if (!rk_finite(cfg->min_quality) || !rk_finite(cfg->min_spread)) {
        return RAKIA_E_NONFINITE;
    }
    if (cfg->min_samples < 3 || cfg->min_spread <= 0.0 || cfg->min_quality < 0.0 ||
        cfg->min_quality > 1.0) {
        return RAKIA_E_RANGE;
    }

    size_t m = 0;
    for (size_t i = 0; i < n; ++i) {
        if (!rk_finite(values[i])) {
            continue;
        }
        if (quality != NULL && !(quality[i] >= cfg->min_quality)) {
            continue; /* also rejects NaN quality */
        }
        scratch[m++] = values[i];
    }
    if (m < cfg->min_samples) {
        return RAKIA_E_INSUFFICIENT;
    }

    double median = 0.0;
    double mad_scaled = 0.0;
    rk_median_mad_inplace(scratch, m, &median, &mad_scaled);
    out->center = median;
    out->spread = (mad_scaled > cfg->min_spread) ? mad_scaled : cfg->min_spread;
    out->n = m;
    return RAKIA_OK;
}

rakia_status rakia_robust_z(double x, const rakia_baseline *baseline, double *out_z)
{
    if (baseline == NULL || out_z == NULL) {
        return RAKIA_E_NULL;
    }
    if (!rk_finite(x) || !rk_finite(baseline->center) || !rk_finite(baseline->spread)) {
        return RAKIA_E_NONFINITE;
    }
    if (!(baseline->spread > 0.0)) {
        return RAKIA_E_DEGENERATE;
    }
    *out_z = (x - baseline->center) / baseline->spread;
    return RAKIA_OK;
}
