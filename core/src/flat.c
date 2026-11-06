/* SPDX-License-Identifier: Apache-2.0
 *
 * Flat ABI (see include/rakia/rakia_flat.h): converts packed arrays to the
 * rakia.h structs and back. No logic of its own beyond argument conversion.
 */
#include <stdint.h>

#include "internal.h"
#include "rakia/rakia_flat.h"

/* 2^53: the largest range in which every integer is exactly a double. */
#define RK_FLAT_MAX_EXACT 9007199254740992.0

/* Converts a double that must hold a count to size_t without loss. */
static rakia_status rk_flat_count(double d, size_t *out)
{
    if (!rk_finite(d)) {
        return RAKIA_E_NONFINITE;
    }
    const double limit = ((double)SIZE_MAX < RK_FLAT_MAX_EXACT) ? (double)SIZE_MAX
                                                                 : RK_FLAT_MAX_EXACT;
    if (!(d >= 0.0) || !(d <= limit)) {
        return RAKIA_E_RANGE;
    }
    const size_t v = (size_t)d;
    if ((double)v < d || (double)v > d) {
        return RAKIA_E_RANGE; /* not integral */
    }
    *out = v;
    return RAKIA_OK;
}

static double rk_flat_from_size(size_t v) { return (double)v; }

static void rk_flat_put_cusum(const rakia_cusum_result *r, double *out)
{
    out[RAKIA_FLAT_CU_ALARM] = (double)r->alarm;
    out[RAKIA_FLAT_CU_DIRECTION] = (double)r->direction;
    out[RAKIA_FLAT_CU_ALARM_INDEX] = rk_flat_from_size(r->alarm_index);
    out[RAKIA_FLAT_CU_ONSET_INDEX] = rk_flat_from_size(r->onset_index);
    out[RAKIA_FLAT_CU_N_USED] = rk_flat_from_size(r->n_used);
    out[RAKIA_FLAT_CU_S_POS] = r->s_pos;
    out[RAKIA_FLAT_CU_S_NEG] = r->s_neg;
}

static rakia_status rk_flat_get_baseline(const double *in, rakia_baseline *b)
{
    b->center = in[RAKIA_FLAT_B_CENTER];
    b->spread = in[RAKIA_FLAT_B_SPREAD];
    return rk_flat_count(in[RAKIA_FLAT_B_N], &b->n);
}

int32_t rakia_flat_abi_version(void) { return RAKIA_FLAT_ABI_VERSION; }

int32_t rakia_flat_baseline_config_default(double *cfg_out)
{
    if (cfg_out == NULL) {
        return RAKIA_E_NULL;
    }
    rakia_baseline_config c;
    rakia_baseline_config_default(&c);
    cfg_out[RAKIA_FLAT_BC_MIN_SAMPLES] = rk_flat_from_size(c.min_samples);
    cfg_out[RAKIA_FLAT_BC_MIN_QUALITY] = c.min_quality;
    cfg_out[RAKIA_FLAT_BC_MIN_SPREAD] = c.min_spread;
    return RAKIA_OK;
}

int32_t rakia_flat_assess_config_default(double *cfg_out)
{
    if (cfg_out == NULL) {
        return RAKIA_E_NULL;
    }
    rakia_assess_config c;
    rakia_assess_config_default(&c);
    cfg_out[RAKIA_FLAT_AC_MIN_SAMPLE_QUALITY] = c.min_sample_quality;
    cfg_out[RAKIA_FLAT_AC_MIN_WINDOW_QUALITY] = c.min_window_quality;
    cfg_out[RAKIA_FLAT_AC_WATCH_Z] = c.watch_z;
    cfg_out[RAKIA_FLAT_AC_ACT_Z] = c.act_z;
    cfg_out[RAKIA_FLAT_AC_CONFIRM_COUNT] = rk_flat_from_size(c.confirm_count);
    cfg_out[RAKIA_FLAT_AC_PERSISTENCE] = rk_flat_from_size(c.persistence);
    cfg_out[RAKIA_FLAT_AC_CUSUM_K] = c.cusum.k;
    cfg_out[RAKIA_FLAT_AC_CUSUM_H] = c.cusum.h;
    return RAKIA_OK;
}

int32_t rakia_flat_quality_assess(const double *values, const uint32_t *sensor_flags, size_t n,
                                  double plausible_min, double plausible_max,
                                  double expected_samples, double *quality_out,
                                  uint32_t *flags_out, double *summary_out)
{
    if (summary_out == NULL) {
        return RAKIA_E_NULL;
    }
    const rakia_quality_config cfg = {plausible_min, plausible_max, expected_samples};
    rakia_quality_summary s;
    const rakia_status st =
        rakia_quality_assess(values, sensor_flags, n, &cfg, quality_out, flags_out, &s);
    if (st != RAKIA_OK) {
        return (int32_t)st;
    }
    summary_out[RAKIA_FLAT_QS_N_TOTAL] = rk_flat_from_size(s.n_total);
    summary_out[RAKIA_FLAT_QS_N_VALID] = rk_flat_from_size(s.n_valid);
    summary_out[RAKIA_FLAT_QS_FRACTION_VALID] = s.fraction_valid;
    summary_out[RAKIA_FLAT_QS_COMPLETENESS] = s.completeness;
    summary_out[RAKIA_FLAT_QS_SCORE] = s.score;
    return RAKIA_OK;
}

int32_t rakia_flat_baseline_compute(const double *values, const double *quality, size_t n,
                                    const double *cfg, double *scratch, double *baseline_out)
{
    if (cfg == NULL || baseline_out == NULL) {
        return RAKIA_E_NULL;
    }
    rakia_baseline_config c;
    const rakia_status cs = rk_flat_count(cfg[RAKIA_FLAT_BC_MIN_SAMPLES], &c.min_samples);
    if (cs != RAKIA_OK) {
        return (int32_t)cs;
    }
    c.min_quality = cfg[RAKIA_FLAT_BC_MIN_QUALITY];
    c.min_spread = cfg[RAKIA_FLAT_BC_MIN_SPREAD];
    rakia_baseline b;
    const rakia_status st = rakia_baseline_compute(values, quality, n, &c, scratch, &b);
    if (st != RAKIA_OK) {
        return (int32_t)st;
    }
    baseline_out[RAKIA_FLAT_B_CENTER] = b.center;
    baseline_out[RAKIA_FLAT_B_SPREAD] = b.spread;
    baseline_out[RAKIA_FLAT_B_N] = rk_flat_from_size(b.n);
    return RAKIA_OK;
}

int32_t rakia_flat_robust_z(double x, const double *baseline, double *out_z)
{
    if (baseline == NULL || out_z == NULL) {
        return RAKIA_E_NULL;
    }
    rakia_baseline b;
    const rakia_status bs = rk_flat_get_baseline(baseline, &b);
    if (bs != RAKIA_OK) {
        return (int32_t)bs;
    }
    return (int32_t)rakia_robust_z(x, &b, out_z);
}

int32_t rakia_flat_cusum(const double *z, size_t n, double k, double h, double *result_out)
{
    if (result_out == NULL) {
        return RAKIA_E_NULL;
    }
    const rakia_cusum_config cfg = {k, h};
    rakia_cusum_result r;
    const rakia_status st = rakia_cusum(z, n, &cfg, &r);
    if (st != RAKIA_OK) {
        return (int32_t)st;
    }
    rk_flat_put_cusum(&r, result_out);
    return RAKIA_OK;
}

int32_t rakia_flat_trend(const double *t, const double *y, size_t n, double *scratch,
                         size_t scratch_len, double *trend_out)
{
    if (trend_out == NULL) {
        return RAKIA_E_NULL;
    }
    rakia_trend tr;
    const rakia_status st = rakia_trend_compute(t, y, n, scratch, scratch_len, &tr);
    if (st != RAKIA_OK) {
        return (int32_t)st;
    }
    trend_out[RAKIA_FLAT_TR_SLOPE] = tr.slope;
    trend_out[RAKIA_FLAT_TR_INTERCEPT] = tr.intercept;
    trend_out[RAKIA_FLAT_TR_MK_S] = tr.mk_s;
    trend_out[RAKIA_FLAT_TR_MK_Z] = tr.mk_z;
    trend_out[RAKIA_FLAT_TR_P_VALUE] = tr.p_value;
    trend_out[RAKIA_FLAT_TR_N] = rk_flat_from_size(tr.n);
    return RAKIA_OK;
}

int32_t rakia_flat_assess(const double *values, const double *quality, size_t n,
                          const double *baseline, const double *cfg, double *z_scratch,
                          double *assessment_out)
{
    if (baseline == NULL || cfg == NULL || assessment_out == NULL) {
        return RAKIA_E_NULL;
    }
    rakia_baseline b;
    rakia_status st = rk_flat_get_baseline(baseline, &b);
    if (st != RAKIA_OK) {
        return (int32_t)st;
    }
    rakia_assess_config c;
    c.min_sample_quality = cfg[RAKIA_FLAT_AC_MIN_SAMPLE_QUALITY];
    c.min_window_quality = cfg[RAKIA_FLAT_AC_MIN_WINDOW_QUALITY];
    c.watch_z = cfg[RAKIA_FLAT_AC_WATCH_Z];
    c.act_z = cfg[RAKIA_FLAT_AC_ACT_Z];
    st = rk_flat_count(cfg[RAKIA_FLAT_AC_CONFIRM_COUNT], &c.confirm_count);
    if (st != RAKIA_OK) {
        return (int32_t)st;
    }
    st = rk_flat_count(cfg[RAKIA_FLAT_AC_PERSISTENCE], &c.persistence);
    if (st != RAKIA_OK) {
        return (int32_t)st;
    }
    c.cusum.k = cfg[RAKIA_FLAT_AC_CUSUM_K];
    c.cusum.h = cfg[RAKIA_FLAT_AC_CUSUM_H];

    rakia_assessment a;
    st = rakia_assess(values, quality, n, &b, &c, z_scratch, &a);
    if (st != RAKIA_OK) {
        return (int32_t)st;
    }
    assessment_out[RAKIA_FLAT_A_LEVEL] = (double)a.level;
    assessment_out[RAKIA_FLAT_A_REASONS] = (double)a.reasons;
    assessment_out[RAKIA_FLAT_A_LATEST_VALUE] = a.latest_value;
    assessment_out[RAKIA_FLAT_A_LATEST_Z] = a.latest_z;
    assessment_out[RAKIA_FLAT_A_DEVIATION] = a.deviation;
    assessment_out[RAKIA_FLAT_A_LATEST_INDEX] = rk_flat_from_size(a.latest_index);
    assessment_out[RAKIA_FLAT_A_N_USABLE] = rk_flat_from_size(a.n_usable);
    assessment_out[RAKIA_FLAT_A_WINDOW_QUALITY] = a.window_quality;
    rk_flat_put_cusum(&a.cusum, assessment_out + RAKIA_FLAT_A_CUSUM);
    return RAKIA_OK;
}

int32_t rakia_flat_record_hash(const uint8_t *id, const uint8_t *subject_id,
                               const char *metric_code, double value, const char *unit,
                               const int64_t *ints, uint32_t method, uint32_t provenance,
                               const uint8_t *prev_hash, uint8_t *hash_out)
{
    if (id == NULL || subject_id == NULL || ints == NULL || prev_hash == NULL ||
        hash_out == NULL) {
        return RAKIA_E_NULL;
    }
    if (method > UINT8_MAX || provenance > UINT8_MAX || ints[RAKIA_FLAT_R_CLIENT_SEQ] < 1) {
        return RAKIA_E_RANGE;
    }
    rakia_record rec;
    for (size_t i = 0; i < sizeof(rec.id); ++i) {
        rec.id[i] = id[i];
        rec.subject_id[i] = subject_id[i];
    }
    for (size_t i = 0; i < RAKIA_HASH_SIZE; ++i) {
        rec.prev_hash[i] = prev_hash[i];
    }
    rec.metric_code = metric_code;
    rec.value = value;
    rec.unit = unit;
    rec.observed_at_us = ints[RAKIA_FLAT_R_OBSERVED_AT_US];
    rec.method = (uint8_t)method;
    rec.provenance = (uint8_t)provenance;
    rec.client_seq = (uint64_t)ints[RAKIA_FLAT_R_CLIENT_SEQ];
    return (int32_t)rakia_record_hash(&rec, hash_out);
}
