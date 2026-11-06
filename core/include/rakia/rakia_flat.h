/*
 * librakia flat ABI - struct-free entry points for foreign-function callers.
 * SPDX-License-Identifier: Apache-2.0
 *
 * EXPERIMENTAL RESEARCH SOFTWARE. Not a medical device.
 *
 * Why this exists: the structs in rakia.h contain size_t and pointer fields,
 * so their layout differs between 64-bit targets, 32-bit Android (armeabi-v7a)
 * and wasm32. Callers such as Dart (dart:ffi and WebAssembly) would otherwise
 * need a separate, hand-maintained layout per target. These functions take
 * only scalars and pointers to arrays of double, uint32_t, uint8_t, int64_t or
 * char, so one marshalling layout works everywhere.
 *
 * Conventions:
 *   - Every function returns a rakia_status as int32_t.
 *   - Configurations and results are packed into double arrays whose element
 *     order is given by the RAKIA_FLAT_* index constants below. Counts and
 *     indices are carried as doubles; they are exact up to 2^53.
 *   - A double that stands for a count must be finite, non-negative and
 *     integral, or the call returns RAKIA_E_RANGE.
 *   - These functions only convert arguments and call the rakia.h API, so
 *     they inherit its validation, determinism and no-allocation guarantees.
 */
#ifndef RAKIA_RAKIA_FLAT_H
#define RAKIA_RAKIA_FLAT_H

#include "rakia/rakia.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Quality summary: rakia_quality_summary. */
enum {
    RAKIA_FLAT_QS_N_TOTAL = 0,
    RAKIA_FLAT_QS_N_VALID = 1,
    RAKIA_FLAT_QS_FRACTION_VALID = 2,
    RAKIA_FLAT_QS_COMPLETENESS = 3,
    RAKIA_FLAT_QS_SCORE = 4,
    RAKIA_FLAT_QS_LEN = 5
};

/* Baseline configuration: rakia_baseline_config. */
enum {
    RAKIA_FLAT_BC_MIN_SAMPLES = 0,
    RAKIA_FLAT_BC_MIN_QUALITY = 1,
    RAKIA_FLAT_BC_MIN_SPREAD = 2,
    RAKIA_FLAT_BC_LEN = 3
};

/* Baseline: rakia_baseline. */
enum {
    RAKIA_FLAT_B_CENTER = 0,
    RAKIA_FLAT_B_SPREAD = 1,
    RAKIA_FLAT_B_N = 2,
    RAKIA_FLAT_B_LEN = 3
};

/* CUSUM result: rakia_cusum_result. */
enum {
    RAKIA_FLAT_CU_ALARM = 0,
    RAKIA_FLAT_CU_DIRECTION = 1,
    RAKIA_FLAT_CU_ALARM_INDEX = 2,
    RAKIA_FLAT_CU_ONSET_INDEX = 3,
    RAKIA_FLAT_CU_N_USED = 4,
    RAKIA_FLAT_CU_S_POS = 5,
    RAKIA_FLAT_CU_S_NEG = 6,
    RAKIA_FLAT_CU_LEN = 7
};

/* Trend: rakia_trend. */
enum {
    RAKIA_FLAT_TR_SLOPE = 0,
    RAKIA_FLAT_TR_INTERCEPT = 1,
    RAKIA_FLAT_TR_MK_S = 2,
    RAKIA_FLAT_TR_MK_Z = 3,
    RAKIA_FLAT_TR_P_VALUE = 4,
    RAKIA_FLAT_TR_N = 5,
    RAKIA_FLAT_TR_LEN = 6
};

/* Assessment configuration: rakia_assess_config. */
enum {
    RAKIA_FLAT_AC_MIN_SAMPLE_QUALITY = 0,
    RAKIA_FLAT_AC_MIN_WINDOW_QUALITY = 1,
    RAKIA_FLAT_AC_WATCH_Z = 2,
    RAKIA_FLAT_AC_ACT_Z = 3,
    RAKIA_FLAT_AC_CONFIRM_COUNT = 4,
    RAKIA_FLAT_AC_PERSISTENCE = 5,
    RAKIA_FLAT_AC_CUSUM_K = 6,
    RAKIA_FLAT_AC_CUSUM_H = 7,
    RAKIA_FLAT_AC_LEN = 8
};

/* Assessment: rakia_assessment, with its CUSUM result appended. */
enum {
    RAKIA_FLAT_A_LEVEL = 0,
    RAKIA_FLAT_A_REASONS = 1,
    RAKIA_FLAT_A_LATEST_VALUE = 2,
    RAKIA_FLAT_A_LATEST_Z = 3,
    RAKIA_FLAT_A_DEVIATION = 4,
    RAKIA_FLAT_A_LATEST_INDEX = 5,
    RAKIA_FLAT_A_N_USABLE = 6,
    RAKIA_FLAT_A_WINDOW_QUALITY = 7,
    RAKIA_FLAT_A_CUSUM = 8, /* RAKIA_FLAT_CU_LEN values follow. */
    RAKIA_FLAT_A_LEN = 8 + RAKIA_FLAT_CU_LEN
};

/* Integer fields of a ledger record, passed as int64_t[2]. */
enum {
    RAKIA_FLAT_R_OBSERVED_AT_US = 0,
    RAKIA_FLAT_R_CLIENT_SEQ = 1, /* Must be >= 1. */
    RAKIA_FLAT_R_LEN = 2
};

/** Version of this flat ABI. Bumped whenever a layout above changes. */
#define RAKIA_FLAT_ABI_VERSION 1
RAKIA_API int32_t rakia_flat_abi_version(void);

/** Writes the rakia.h defaults into cfg_out[RAKIA_FLAT_BC_LEN]. */
RAKIA_API int32_t rakia_flat_baseline_config_default(double *cfg_out);

/** Writes the rakia.h defaults into cfg_out[RAKIA_FLAT_AC_LEN]. */
RAKIA_API int32_t rakia_flat_assess_config_default(double *cfg_out);

/** rakia_quality_assess. flags_out and sensor_flags are nullable. */
RAKIA_API int32_t rakia_flat_quality_assess(const double *values, const uint32_t *sensor_flags,
                                            size_t n, double plausible_min, double plausible_max,
                                            double expected_samples, double *quality_out,
                                            uint32_t *flags_out, double *summary_out);

/** rakia_baseline_compute. quality is nullable; scratch holds n doubles. */
RAKIA_API int32_t rakia_flat_baseline_compute(const double *values, const double *quality,
                                              size_t n, const double *cfg, double *scratch,
                                              double *baseline_out);

/** rakia_robust_z with baseline[RAKIA_FLAT_B_LEN]. */
RAKIA_API int32_t rakia_flat_robust_z(double x, const double *baseline, double *out_z);

/** rakia_cusum with allowance k and threshold h. */
RAKIA_API int32_t rakia_flat_cusum(const double *z, size_t n, double k, double h,
                                   double *result_out);

/** rakia_trend_compute. */
RAKIA_API int32_t rakia_flat_trend(const double *t, const double *y, size_t n, double *scratch,
                                   size_t scratch_len, double *trend_out);

/** rakia_assess. quality is nullable; z_scratch holds n doubles. */
RAKIA_API int32_t rakia_flat_assess(const double *values, const double *quality, size_t n,
                                    const double *baseline, const double *cfg, double *z_scratch,
                                    double *assessment_out);

/**
 * rakia_record_hash. id and subject_id are 16 bytes, prev_hash 32 bytes,
 * metric_code and unit are NUL-terminated ASCII, ints is int64_t[RAKIA_FLAT_R_LEN].
 */
RAKIA_API int32_t rakia_flat_record_hash(const uint8_t *id, const uint8_t *subject_id,
                                         const char *metric_code, double value, const char *unit,
                                         const int64_t *ints, uint32_t method,
                                         uint32_t provenance, const uint8_t *prev_hash,
                                         uint8_t *hash_out);

#ifdef __cplusplus
}
#endif

#endif /* RAKIA_RAKIA_FLAT_H */
