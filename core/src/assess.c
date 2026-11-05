/* SPDX-License-Identifier: Apache-2.0
 *
 * Quality-gated assessment of one metric against a personal baseline.
 * Rules (engineering defaults, not clinical thresholds):
 *   no usable samples                      -> INSUFFICIENT_DATA
 *   usable fraction < min_window_quality   -> DATA_QUALITY (no health level)
 *   |latest z| >= watch_z, or a CUSUM alarm supported by >= 2 usable
 *     samples from onset to alarm (a sustained shift)               -> WATCH
 *   sustained shift, >= `persistence` usable samples after the alarm, and a
 *     strict majority of them still shifted (z * direction > k)     -> ACT
 *   latest `confirm_count` usable samples all |z| >= act_z, same sign -> ACT
 * A single extreme value is never enough for ACT: it asks for confirmation.
 */
#include "internal.h"

void rakia_assess_config_default(rakia_assess_config *cfg)
{
    if (cfg == NULL) {
        return;
    }
    cfg->min_sample_quality = 0.5;
    cfg->min_window_quality = 0.7;
    cfg->watch_z = 2.5;
    cfg->act_z = 4.0;
    cfg->confirm_count = 2;
    cfg->persistence = 3;
    rakia_cusum_config_default(&cfg->cusum);
}

static rakia_status rk_check_config(const rakia_assess_config *c)
{
    if (!rk_finite(c->min_sample_quality) || !rk_finite(c->min_window_quality) ||
        !rk_finite(c->watch_z) || !rk_finite(c->act_z)) {
        return RAKIA_E_NONFINITE;
    }
    if (c->min_sample_quality < 0.0 || c->min_sample_quality > 1.0 ||
        c->min_window_quality < 0.0 || c->min_window_quality > 1.0 || !(c->watch_z > 0.0) ||
        c->act_z < c->watch_z || c->confirm_count < 2 || c->persistence < 1) {
        return RAKIA_E_RANGE;
    }
    return RAKIA_OK;
}

rakia_status rakia_assess(const double *values, const double *quality, size_t n,
                          const rakia_baseline *baseline, const rakia_assess_config *cfg,
                          double *z_scratch, rakia_assessment *out)
{
    if (values == NULL || baseline == NULL || cfg == NULL || z_scratch == NULL || out == NULL) {
        return RAKIA_E_NULL;
    }
    if (n == 0) {
        return RAKIA_E_EMPTY;
    }
    if (z_scratch == values) {
        return RAKIA_E_RANGE;
    }
    if (!rk_finite(baseline->center) || !rk_finite(baseline->spread)) {
        return RAKIA_E_NONFINITE;
    }
    if (!(baseline->spread > 0.0)) {
        return RAKIA_E_DEGENERATE;
    }
    rakia_status st = rk_check_config(cfg);
    if (st != RAKIA_OK) {
        return st;
    }

    size_t usable = 0;
    size_t latest = 0;
    for (size_t i = 0; i < n; ++i) {
        const double v = values[i];
        int ok = rk_finite(v);
        if (ok && quality != NULL) {
            ok = quality[i] >= cfg->min_sample_quality;
        }
        if (ok) {
            z_scratch[i] = (v - baseline->center) / baseline->spread;
            ++usable;
            latest = i;
        } else {
            z_scratch[i] = NAN;
        }
    }

    out->level = RAKIA_LEVEL_INSUFFICIENT_DATA;
    out->reasons = 0;
    out->latest_value = NAN;
    out->latest_z = NAN;
    out->deviation = NAN;
    out->latest_index = 0;
    out->n_usable = usable;
    out->window_quality = (double)usable / (double)n;
    out->cusum.alarm = 0;
    out->cusum.direction = 0;
    out->cusum.alarm_index = 0;
    out->cusum.onset_index = 0;
    out->cusum.n_used = 0;
    out->cusum.s_pos = 0.0;
    out->cusum.s_neg = 0.0;

    if (usable == 0) {
        out->reasons = RAKIA_REASON_NO_VALID_DATA;
        return RAKIA_OK;
    }
    out->latest_index = latest;
    out->latest_value = values[latest];
    out->latest_z = z_scratch[latest];
    out->deviation = values[latest] - baseline->center;

    if (out->window_quality < cfg->min_window_quality) {
        out->level = RAKIA_LEVEL_DATA_QUALITY;
        out->reasons = RAKIA_REASON_LOW_QUALITY;
        return RAKIA_OK;
    }

    st = rakia_cusum(z_scratch, n, &cfg->cusum, &out->cusum);
    if (st != RAKIA_OK) {
        return st;
    }

    rakia_level level = RAKIA_LEVEL_WITHIN_BASELINE;
    uint32_t reasons = 0;
    if (fabs(out->latest_z) >= cfg->watch_z) {
        level = RAKIA_LEVEL_WATCH;
        reasons |= RAKIA_REASON_POINT_DEVIATION;
    }
    /* A CUSUM alarm driven by one sample is a point deviation, not a
     * sustained shift: require at least two usable samples from onset to alarm. */
    int sustained = 0;
    if (out->cusum.alarm) {
        size_t contributing = 0;
        for (size_t i = out->cusum.onset_index; i <= out->cusum.alarm_index; ++i) {
            if (rk_finite(z_scratch[i])) {
                ++contributing;
            }
        }
        sustained = contributing >= 2;
    }
    if (sustained) {
        level = RAKIA_LEVEL_WATCH;
        reasons |= RAKIA_REASON_SUSTAINED_SHIFT;

        /* Persistence: at least `persistence` usable samples after the alarm,
         * and a strict majority of them still shifted (z * direction > k),
         * i.e. the post-alarm median remains beyond the allowance. */
        const double dir = (double)out->cusum.direction;
        size_t after = 0;
        size_t shifted = 0;
        for (size_t i = out->cusum.alarm_index + 1; i < n; ++i) {
            const double z = z_scratch[i];
            if (!rk_finite(z)) {
                continue;
            }
            ++after;
            if (z * dir > cfg->cusum.k) {
                ++shifted;
            }
        }
        if (after >= cfg->persistence && 2 * shifted > after) {
            level = RAKIA_LEVEL_ACT;
            reasons |= RAKIA_REASON_PERSISTENT_SHIFT;
        }
    }

    /* Trailing consecutive extreme values with the same sign. */
    {
        size_t run = 0;
        int sign = 0;
        for (size_t i = n; i-- > 0;) {
            const double z = z_scratch[i];
            if (!rk_finite(z)) {
                continue;
            }
            const int s = (z > 0.0) ? 1 : -1;
            if (fabs(z) >= cfg->act_z && (run == 0 || s == sign)) {
                sign = s;
                ++run;
            } else {
                break;
            }
        }
        if (run >= cfg->confirm_count) {
            level = RAKIA_LEVEL_ACT;
            reasons |= RAKIA_REASON_CONFIRMED_EXTREME;
        }
    }

    out->level = level;
    out->reasons = reasons;
    return RAKIA_OK;
}
