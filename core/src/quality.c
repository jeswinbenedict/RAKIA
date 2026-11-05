/* SPDX-License-Identifier: Apache-2.0 */
#include "internal.h"

rakia_status rakia_quality_assess(const double *values, const uint32_t *sensor_flags, size_t n,
                                  const rakia_quality_config *cfg, double *quality_out,
                                  uint32_t *flags_out, rakia_quality_summary *summary)
{
    if (values == NULL || cfg == NULL || quality_out == NULL || summary == NULL) {
        return RAKIA_E_NULL;
    }
    if (n == 0) {
        return RAKIA_E_EMPTY;
    }
    if (!rk_finite(cfg->plausible_min) || !rk_finite(cfg->plausible_max) ||
        !rk_finite(cfg->expected_samples)) {
        return RAKIA_E_NONFINITE;
    }
    if (cfg->plausible_min > cfg->plausible_max || cfg->expected_samples < 0.0) {
        return RAKIA_E_RANGE;
    }

    size_t valid = 0;
    for (size_t i = 0; i < n; ++i) {
        uint32_t flags = 0;
        const double v = values[i];
        if (!rk_finite(v)) {
            flags |= RAKIA_QF_NONFINITE;
        } else if (v < cfg->plausible_min || v > cfg->plausible_max) {
            flags |= RAKIA_QF_IMPLAUSIBLE;
        }
        if (sensor_flags != NULL && sensor_flags[i] != 0) {
            flags |= RAKIA_QF_SENSOR;
        }
        quality_out[i] = (flags == 0) ? 1.0 : 0.0;
        if (flags_out != NULL) {
            flags_out[i] = flags;
        }
        if (flags == 0) {
            ++valid;
        }
    }

    summary->n_total = n;
    summary->n_valid = valid;
    summary->fraction_valid = (double)valid / (double)n;
    if (cfg->expected_samples > 0.0) {
        const double c = (double)valid / cfg->expected_samples;
        summary->completeness = (c > 1.0) ? 1.0 : c;
    } else {
        summary->completeness = 1.0;
    }
    summary->score = summary->fraction_valid * summary->completeness;
    return RAKIA_OK;
}
