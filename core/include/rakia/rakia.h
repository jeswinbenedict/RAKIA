/*
 * librakia - portable analytics core for RAKIA.
 * SPDX-License-Identifier: Apache-2.0
 *
 * EXPERIMENTAL RESEARCH SOFTWARE. Not a medical device. The algorithms in this
 * library flag statistical changes relative to a person's own baseline; they
 * do not diagnose and have not been clinically validated.
 *
 * Design rules (see docs/algorithms/LIBRAKIA.md):
 *   - C11, no global mutable state, thread-safe by construction.
 *   - No heap allocation: callers provide every buffer.
 *   - Every function validates its arguments and returns a rakia_status.
 *   - Deterministic: identical inputs give identical outputs on every
 *     platform (except p-values, which rely on the platform's erfc()).
 */
#ifndef RAKIA_RAKIA_H
#define RAKIA_RAKIA_H

#include <stddef.h>
#include <stdint.h>

#if defined(RAKIA_SHARED)
#  if defined(_WIN32)
#    if defined(RAKIA_BUILDING)
#      define RAKIA_API __declspec(dllexport)
#    else
#      define RAKIA_API __declspec(dllimport)
#    endif
#  else
#    define RAKIA_API __attribute__((visibility("default")))
#  endif
#else
#  define RAKIA_API
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* ------------------------------------------------------------------------ */
/* Version and status                                                       */
/* ------------------------------------------------------------------------ */

#define RAKIA_VERSION_MAJOR 0
#define RAKIA_VERSION_MINOR 1
#define RAKIA_VERSION_PATCH 0

/** Library version string, e.g. "0.1.0". Never NULL. */
RAKIA_API const char *rakia_version(void);

typedef enum rakia_status {
    RAKIA_OK = 0,
    RAKIA_E_NULL = 1,         /**< A required pointer argument was NULL. */
    RAKIA_E_EMPTY = 2,        /**< An input had zero length. */
    RAKIA_E_NONFINITE = 3,    /**< NaN or infinity where a finite value is required. */
    RAKIA_E_RANGE = 4,        /**< A parameter or input is outside its valid range. */
    RAKIA_E_BUFFER = 5,       /**< A caller-provided buffer is too small. */
    RAKIA_E_INSUFFICIENT = 6, /**< Not enough valid data for a reliable result. */
    RAKIA_E_SINGULAR = 7,     /**< Matrix is not symmetric positive definite. */
    RAKIA_E_DEGENERATE = 8    /**< Zero or non-positive spread; cannot standardise. */
} rakia_status;

/** Short, stable, English description of a status code. Never NULL. */
RAKIA_API const char *rakia_status_str(rakia_status status);

/* ------------------------------------------------------------------------ */
/* Robust statistics                                                        */
/* ------------------------------------------------------------------------ */

/** Scale factor that makes the MAD a consistent estimator of the standard
 *  deviation for normally distributed data. */
#define RAKIA_MAD_SCALE 1.482602218505602

/**
 * Median of x[0..n). `scratch` must hold n doubles and may alias nothing
 * else. All values must be finite.
 */
RAKIA_API rakia_status rakia_median(const double *x, size_t n, double *scratch,
                                    double *out_median);

/**
 * Median and scaled median absolute deviation (MAD * RAKIA_MAD_SCALE).
 * `scratch` must hold n doubles. All values must be finite.
 */
RAKIA_API rakia_status rakia_median_mad(const double *x, size_t n, double *scratch,
                                        double *out_median, double *out_mad_scaled);

/* ------------------------------------------------------------------------ */
/* Data quality gate                                                        */
/* ------------------------------------------------------------------------ */

/** Per-sample quality flags (bitmask). */
#define RAKIA_QF_NONFINITE  (1u << 0) /**< Value was NaN or infinite. */
#define RAKIA_QF_IMPLAUSIBLE (1u << 1) /**< Outside the metric's plausible range. */
#define RAKIA_QF_SENSOR     (1u << 2) /**< Device reported a sensor problem. */

typedef struct rakia_quality_config {
    double plausible_min;    /**< Physiologically plausible lower bound (inclusive). */
    double plausible_max;    /**< Physiologically plausible upper bound (inclusive). */
    double expected_samples; /**< Samples expected in the window; 0 disables completeness. */
} rakia_quality_config;

typedef struct rakia_quality_summary {
    size_t n_total;       /**< Samples supplied. */
    size_t n_valid;       /**< Samples that passed every check. */
    double fraction_valid;/**< n_valid / n_total. */
    double completeness;  /**< min(1, n_valid / expected_samples), or 1 if disabled. */
    double score;         /**< fraction_valid * completeness, in [0, 1]. */
} rakia_quality_summary;

/**
 * Scores each sample: quality_out[i] is 1.0 for a valid sample and 0.0 for a
 * sample that is non-finite, implausible, or sensor-flagged. Writes the
 * reason bits to flags_out[i] when flags_out is not NULL. `sensor_flags`
 * (nullable) is a per-sample non-zero marker from the device.
 */
RAKIA_API rakia_status rakia_quality_assess(const double *values, const uint32_t *sensor_flags,
                                            size_t n, const rakia_quality_config *cfg,
                                            double *quality_out, uint32_t *flags_out,
                                            rakia_quality_summary *summary);

/* ------------------------------------------------------------------------ */
/* Personal baseline                                                        */
/* ------------------------------------------------------------------------ */

typedef struct rakia_baseline_config {
    size_t min_samples; /**< Minimum valid samples required (>= 3). */
    double min_quality; /**< Samples with quality below this are excluded. */
    double min_spread;  /**< Floor for the spread, in the metric's unit (> 0). */
} rakia_baseline_config;

typedef struct rakia_baseline {
    double center; /**< Median of the reference window. */
    double spread; /**< max(MAD * RAKIA_MAD_SCALE, min_spread). */
    size_t n;      /**< Valid samples used. */
} rakia_baseline;

/** Fills cfg with documented defaults (min_samples 14, min_quality 0.5,
 *  min_spread 1e-6). min_spread should be overridden per metric. */
RAKIA_API void rakia_baseline_config_default(rakia_baseline_config *cfg);

/**
 * Robust baseline over a reference window. `quality` (nullable) is per-sample
 * quality from rakia_quality_assess; non-finite values are always excluded.
 * `scratch` must hold n doubles. Returns RAKIA_E_INSUFFICIENT when fewer than
 * cfg->min_samples samples are usable.
 */
RAKIA_API rakia_status rakia_baseline_compute(const double *values, const double *quality,
                                              size_t n, const rakia_baseline_config *cfg,
                                              double *scratch, rakia_baseline *out);

/** Robust z-score of x against a baseline: (x - center) / spread. */
RAKIA_API rakia_status rakia_robust_z(double x, const rakia_baseline *baseline, double *out_z);

/* ------------------------------------------------------------------------ */
/* Sustained change: two-sided CUSUM with onset estimate                    */
/* ------------------------------------------------------------------------ */

typedef struct rakia_cusum_config {
    double k; /**< Allowance (reference value) in SD units, >= 0. Default 0.5. */
    double h; /**< Decision threshold in SD units, > 0. Default 8.0. */
} rakia_cusum_config;

typedef struct rakia_cusum_result {
    int alarm;          /**< 1 if a threshold was crossed, else 0. */
    int direction;      /**< +1 upward shift, -1 downward shift, 0 none. */
    size_t alarm_index; /**< First index at which the threshold was crossed. */
    size_t onset_index; /**< Estimated first index of the change. */
    size_t n_used;      /**< Finite samples processed. */
    double s_pos;       /**< Upper statistic at alarm (or at end). */
    double s_neg;       /**< Lower statistic at alarm (or at end), as a positive number. */
} rakia_cusum_result;

RAKIA_API void rakia_cusum_config_default(rakia_cusum_config *cfg);

/**
 * Runs a two-sided tabular CUSUM over standardised residuals z[0..n) (for
 * example robust z-scores) and stops at the first alarm. Non-finite entries
 * are treated as missing and skipped. The onset is the first sample after the
 * triggering statistic last equalled zero.
 */
RAKIA_API rakia_status rakia_cusum(const double *z, size_t n, const rakia_cusum_config *cfg,
                                   rakia_cusum_result *out);

/* ------------------------------------------------------------------------ */
/* Trend: Theil-Sen slope and Mann-Kendall test                             */
/* ------------------------------------------------------------------------ */

/** Largest series accepted by rakia_trend (keeps scratch below ~4 MiB). */
#define RAKIA_TREND_MAX_N 1024u

typedef struct rakia_trend {
    double slope;     /**< Theil-Sen slope, in value units per time unit. */
    double intercept; /**< median(y - slope * t). */
    double mk_s;      /**< Mann-Kendall S statistic. */
    double mk_z;      /**< Continuity-corrected normal score. */
    double p_value;   /**< Two-sided p-value (normal approximation). */
    size_t n;         /**< Samples used. */
} rakia_trend;

/** Scratch doubles needed by rakia_trend for n samples. */
RAKIA_API size_t rakia_trend_scratch_size(size_t n);

/**
 * Theil-Sen slope with Mann-Kendall significance. t must be non-decreasing;
 * all values finite; 3 <= n <= RAKIA_TREND_MAX_N. Pairs with equal t do not
 * contribute a slope. The normal approximation is reliable from n >= 10.
 */
RAKIA_API rakia_status rakia_trend_compute(const double *t, const double *y, size_t n,
                                           double *scratch, size_t scratch_len,
                                           rakia_trend *out);

/* ------------------------------------------------------------------------ */
/* Multivariate: robust Mahalanobis distance with contributions            */
/* ------------------------------------------------------------------------ */

/** Largest feature dimension supported. */
#define RAKIA_MV_MAX_D 32u

/**
 * Correlation matrix (row-major d*d) of standardised samples X (row-major
 * n*d), using rows where every feature is finite, shrunk towards identity:
 * R = (1 - shrinkage) * C + shrinkage * I, with shrinkage in [0, 1].
 * Requires at least d + 2 complete rows.
 */
RAKIA_API rakia_status rakia_correlation(const double *x, size_t n, size_t d, double shrinkage,
                                         double *corr_out);

/**
 * Squared Mahalanobis distance D^2 = z' R^-1 z for a vector of standardised
 * deviations z (length d) and a correlation matrix R (row-major d*d).
 * `work` must hold d*d + d doubles. contrib_out (nullable, length d) receives
 * z_i * (R^-1 z)_i; the contributions sum to D^2 and may be negative when
 * features are correlated.
 */
RAKIA_API rakia_status rakia_mahalanobis(const double *z, const double *corr, size_t d,
                                         double *work, double *d2_out, double *contrib_out);

/* ------------------------------------------------------------------------ */
/* Ledger: SHA-256 and hash-chained measurement records                     */
/* ------------------------------------------------------------------------ */

#define RAKIA_HASH_SIZE 32u
#define RAKIA_MAX_CODE_LEN 64u
#define RAKIA_MAX_UNIT_LEN 32u
/** Upper bound on the canonical encoding length of one record. */
#define RAKIA_RECORD_MAX_ENCODED 256u

/** One-shot SHA-256 (FIPS 180-4). */
RAKIA_API rakia_status rakia_sha256(const void *data, size_t len, uint8_t out[RAKIA_HASH_SIZE]);

typedef enum rakia_method {
    RAKIA_METHOD_MEASURED = 1,
    RAKIA_METHOD_MANUAL = 2,
    RAKIA_METHOD_ESTIMATED = 3,
    RAKIA_METHOD_DERIVED = 4
} rakia_method;

typedef enum rakia_provenance {
    RAKIA_PROVENANCE_REAL = 1,
    RAKIA_PROVENANCE_IMPORTED = 2,
    RAKIA_PROVENANCE_SIMULATED = 3
} rakia_provenance;

typedef struct rakia_record {
    uint8_t id[16];             /**< Measurement UUID (bytes). */
    uint8_t subject_id[16];     /**< Crew member UUID (bytes). */
    const char *metric_code;    /**< ASCII [a-z0-9_.], 1..RAKIA_MAX_CODE_LEN bytes. */
    double value;               /**< Finite value in `unit`. */
    const char *unit;           /**< UCUM code, printable ASCII, 1..RAKIA_MAX_UNIT_LEN bytes. */
    int64_t observed_at_us;     /**< Microseconds since Unix epoch, UTC. */
    uint8_t method;             /**< rakia_method. */
    uint8_t provenance;         /**< rakia_provenance. */
    uint64_t client_seq;        /**< Per-device sequence number, starting at 1. */
    uint8_t prev_hash[RAKIA_HASH_SIZE]; /**< Hash of the previous record. */
} rakia_record;

/** Canonical, platform-independent byte encoding of a record (format v1). */
RAKIA_API rakia_status rakia_record_encode(const rakia_record *rec, uint8_t *buf, size_t cap,
                                           size_t *len_out);

/** SHA-256 of the canonical encoding. */
RAKIA_API rakia_status rakia_record_hash(const rakia_record *rec, uint8_t out[RAKIA_HASH_SIZE]);

/**
 * Verifies a chain: each record's prev_hash links to the previous hash
 * (genesis for the first), client_seq increases by exactly 1, and each hash
 * matches. On RAKIA_E_RANGE, *first_bad (nullable) holds the first failing
 * index.
 */
RAKIA_API rakia_status rakia_chain_verify(const rakia_record *records,
                                          const uint8_t (*hashes)[RAKIA_HASH_SIZE], size_t n,
                                          const uint8_t genesis[RAKIA_HASH_SIZE],
                                          size_t *first_bad);

/* ------------------------------------------------------------------------ */
/* Assessment: quality-gated, explainable status for one metric             */
/* ------------------------------------------------------------------------ */

typedef enum rakia_level {
    RAKIA_LEVEL_INSUFFICIENT_DATA = 0, /**< Nothing to assess yet. */
    RAKIA_LEVEL_DATA_QUALITY = 1,      /**< Data problem, not a health signal. */
    RAKIA_LEVEL_WITHIN_BASELINE = 2,
    RAKIA_LEVEL_WATCH = 3,
    RAKIA_LEVEL_ACT = 4
} rakia_level;

/** Reason bits explaining an assessment. */
#define RAKIA_REASON_POINT_DEVIATION   (1u << 0) /**< Latest value far from baseline. */
#define RAKIA_REASON_SUSTAINED_SHIFT   (1u << 1) /**< CUSUM detected a sustained shift. */
#define RAKIA_REASON_PERSISTENT_SHIFT  (1u << 2) /**< Shift persisted after detection. */
#define RAKIA_REASON_CONFIRMED_EXTREME (1u << 3) /**< Consecutive extreme values. */
#define RAKIA_REASON_LOW_QUALITY       (1u << 4) /**< Window failed the quality gate. */
#define RAKIA_REASON_NO_VALID_DATA     (1u << 5) /**< No usable samples. */

typedef struct rakia_assess_config {
    double min_sample_quality; /**< Samples below this are ignored. Default 0.5. */
    double min_window_quality; /**< Fraction of usable samples required. Default 0.7. */
    double watch_z;            /**< |z| at or above this: WATCH. Default 2.5. */
    double act_z;              /**< |z| for a confirmed extreme. Default 4.0. */
    size_t confirm_count;      /**< Consecutive same-sign extremes for ACT. Default 2. */
    size_t persistence;        /**< Samples after a CUSUM alarm for ACT. Default 3. */
    rakia_cusum_config cusum;
} rakia_assess_config;

typedef struct rakia_assessment {
    rakia_level level;
    uint32_t reasons;      /**< RAKIA_REASON_* bits. */
    double latest_value;   /**< Most recent usable value (NaN if none). */
    double latest_z;       /**< Its robust z-score (NaN if none). */
    double deviation;      /**< latest_value - baseline center. */
    size_t latest_index;   /**< Index of the latest usable sample. */
    size_t n_usable;       /**< Samples that passed the quality threshold. */
    double window_quality; /**< n_usable / n. */
    rakia_cusum_result cusum;
} rakia_assessment;

RAKIA_API void rakia_assess_config_default(rakia_assess_config *cfg);

/**
 * Assesses a time-ordered window of one metric against a baseline. `quality`
 * is nullable (all samples treated as quality 1). `z_scratch` must hold n
 * doubles and receives the per-sample robust z (NaN where unusable).
 */
RAKIA_API rakia_status rakia_assess(const double *values, const double *quality, size_t n,
                                    const rakia_baseline *baseline,
                                    const rakia_assess_config *cfg, double *z_scratch,
                                    rakia_assessment *out);

#ifdef __cplusplus
}
#endif

#endif /* RAKIA_RAKIA_H */
