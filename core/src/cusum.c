/* SPDX-License-Identifier: Apache-2.0 */
#include "internal.h"

void rakia_cusum_config_default(rakia_cusum_config *cfg)
{
    if (cfg == NULL) {
        return;
    }
    /* h = 8 rather than the textbook 5: baselines are estimated from small
     * personal samples, which inflates false alarms (see LIBRAKIA.md, §5). */
    cfg->k = 0.5;
    cfg->h = 8.0;
}

rakia_status rakia_cusum(const double *z, size_t n, const rakia_cusum_config *cfg,
                         rakia_cusum_result *out)
{
    if (z == NULL || cfg == NULL || out == NULL) {
        return RAKIA_E_NULL;
    }
    if (n == 0) {
        return RAKIA_E_EMPTY;
    }
    if (!rk_finite(cfg->k) || !rk_finite(cfg->h)) {
        return RAKIA_E_NONFINITE;
    }
    if (cfg->k < 0.0 || !(cfg->h > 0.0)) {
        return RAKIA_E_RANGE;
    }

    double s_pos = 0.0;
    double s_neg = 0.0;
    /* "start" = first finite index after the statistic was last zero.
     * pending_* marks that the next finite sample becomes the start. */
    size_t start_pos = 0;
    size_t start_neg = 0;
    int pending_pos = 1;
    int pending_neg = 1;
    size_t used = 0;

    out->alarm = 0;
    out->direction = 0;
    out->alarm_index = 0;
    out->onset_index = 0;

    for (size_t i = 0; i < n; ++i) {
        const double x = z[i];
        if (!rk_finite(x)) {
            continue; /* missing sample */
        }
        ++used;
        if (pending_pos) {
            start_pos = i;
            pending_pos = 0;
        }
        if (pending_neg) {
            start_neg = i;
            pending_neg = 0;
        }

        s_pos = s_pos + x - cfg->k;
        if (s_pos <= 0.0) {
            s_pos = 0.0;
            pending_pos = 1;
        }
        s_neg = s_neg - x - cfg->k;
        if (s_neg <= 0.0) {
            s_neg = 0.0;
            pending_neg = 1;
        }

        const int up = s_pos > cfg->h;
        const int down = s_neg > cfg->h;
        if (up || down) {
            out->alarm = 1;
            out->alarm_index = i;
            /* If both cross on the same sample, the larger excursion wins. */
            if (up && (!down || s_pos >= s_neg)) {
                out->direction = 1;
                out->onset_index = start_pos;
            } else {
                out->direction = -1;
                out->onset_index = start_neg;
            }
            break;
        }
    }

    out->n_used = used;
    out->s_pos = s_pos;
    out->s_neg = s_neg;
    if (used == 0) {
        return RAKIA_E_INSUFFICIENT;
    }
    return RAKIA_OK;
}
