/* SPDX-License-Identifier: Apache-2.0 */
#ifndef RAKIA_INTERNAL_H
#define RAKIA_INTERNAL_H

#include <math.h>
#include <stddef.h>

#include "rakia/rakia.h"

/* librakia relies on IEEE 754 binary64 doubles for determinism. */
typedef char rk_static_assert_double_is_64bit[(sizeof(double) == 8) ? 1 : -1];

static inline int rk_finite(double x) { return isfinite(x) ? 1 : 0; }

/* Sorts buf[0..n) ascending (all values finite). */
void rk_sort(double *buf, size_t n);

/* Median of an already sorted buffer. n > 0. */
double rk_sorted_median(const double *sorted, size_t n);

/*
 * Sorts buf in place, writes the median, then overwrites buf with absolute
 * deviations and writes MAD * RAKIA_MAD_SCALE. n > 0, all values finite.
 */
void rk_median_mad_inplace(double *buf, size_t n, double *median, double *mad_scaled);

#endif /* RAKIA_INTERNAL_H */
