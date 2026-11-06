/* SPDX-License-Identifier: Apache-2.0
 * The flat ABI must give bit-identical results to the struct API it wraps,
 * and must reject counts that cannot be represented exactly. */
#include <string.h>

#include "rakia/rakia_flat.h"
#include "rk_test.h"

#define N 80

static int same_bits(double a, double b) { return memcmp(&a, &b, sizeof(double)) == 0; }

static void make_series(double *ref, double *mon)
{
    rk_rng rng = {UINT64_C(42)};
    for (int i = 0; i < N; ++i) {
        ref[i] = 60.0 + 2.0 * rk_rng_normal(&rng);
        mon[i] = 60.0 + (i >= 40 ? 4.0 : 0.0) + 2.0 * rk_rng_normal(&rng);
    }
    mon[7] = NAN; /* exercises the missing-sample path */
}

static void test_defaults(void)
{
    double bc[RAKIA_FLAT_BC_LEN];
    double ac[RAKIA_FLAT_AC_LEN];
    CHECK(rakia_flat_abi_version() == RAKIA_FLAT_ABI_VERSION);
    CHECK_STATUS((rakia_status)rakia_flat_baseline_config_default(bc), RAKIA_OK);
    CHECK_STATUS((rakia_status)rakia_flat_assess_config_default(ac), RAKIA_OK);
    rakia_baseline_config b;
    rakia_baseline_config_default(&b);
    rakia_assess_config a;
    rakia_assess_config_default(&a);
    CHECK(same_bits(bc[RAKIA_FLAT_BC_MIN_SAMPLES], (double)b.min_samples));
    CHECK(same_bits(bc[RAKIA_FLAT_BC_MIN_QUALITY], b.min_quality));
    CHECK(same_bits(bc[RAKIA_FLAT_BC_MIN_SPREAD], b.min_spread));
    CHECK(same_bits(ac[RAKIA_FLAT_AC_WATCH_Z], a.watch_z));
    CHECK(same_bits(ac[RAKIA_FLAT_AC_ACT_Z], a.act_z));
    CHECK(same_bits(ac[RAKIA_FLAT_AC_CONFIRM_COUNT], (double)a.confirm_count));
    CHECK(same_bits(ac[RAKIA_FLAT_AC_PERSISTENCE], (double)a.persistence));
    CHECK(same_bits(ac[RAKIA_FLAT_AC_CUSUM_K], a.cusum.k));
    CHECK(same_bits(ac[RAKIA_FLAT_AC_CUSUM_H], a.cusum.h));
    CHECK_STATUS((rakia_status)rakia_flat_baseline_config_default(NULL), RAKIA_E_NULL);
    CHECK_STATUS((rakia_status)rakia_flat_assess_config_default(NULL), RAKIA_E_NULL);
}

static void test_quality_matches(void)
{
    const double v[6] = {60.0, NAN, 250.0, 61.0, 59.0, 62.0};
    const uint32_t sensor[6] = {0, 0, 0, 1, 0, 0};
    double q1[6];
    double q2[6];
    uint32_t f1[6];
    uint32_t f2[6];
    double s[RAKIA_FLAT_QS_LEN];
    const rakia_quality_config cfg = {20.0, 220.0, 8.0};
    rakia_quality_summary ref;
    CHECK_STATUS(rakia_quality_assess(v, sensor, 6, &cfg, q1, f1, &ref), RAKIA_OK);
    CHECK_STATUS((rakia_status)rakia_flat_quality_assess(v, sensor, 6, 20.0, 220.0, 8.0, q2, f2, s),
                 RAKIA_OK);
    CHECK(memcmp(q1, q2, sizeof(q1)) == 0);
    CHECK(memcmp(f1, f2, sizeof(f1)) == 0);
    CHECK(same_bits(s[RAKIA_FLAT_QS_N_TOTAL], (double)ref.n_total));
    CHECK(same_bits(s[RAKIA_FLAT_QS_N_VALID], (double)ref.n_valid));
    CHECK(same_bits(s[RAKIA_FLAT_QS_SCORE], ref.score));
    CHECK(same_bits(s[RAKIA_FLAT_QS_COMPLETENESS], ref.completeness));
    CHECK_STATUS((rakia_status)rakia_flat_quality_assess(v, sensor, 6, 20.0, 220.0, 8.0, q2, f2,
                                                         NULL),
                 RAKIA_E_NULL);
    /* Errors from the wrapped function pass through unchanged. */
    CHECK_STATUS((rakia_status)rakia_flat_quality_assess(v, sensor, 6, 220.0, 20.0, 8.0, q2, f2, s),
                 rakia_quality_assess(v, sensor, 6,
                                      &(rakia_quality_config){220.0, 20.0, 8.0}, q1, f1, &ref));
}

static void test_assess_matches(void)
{
    double ref[N];
    double mon[N];
    double scratch[N];
    double z1[N];
    double z2[N];
    make_series(ref, mon);

    rakia_baseline_config bcfg;
    rakia_baseline_config_default(&bcfg);
    bcfg.min_spread = 0.5;
    rakia_baseline b;
    CHECK_STATUS(rakia_baseline_compute(ref, NULL, N, &bcfg, scratch, &b), RAKIA_OK);

    double fbc[RAKIA_FLAT_BC_LEN];
    double fb[RAKIA_FLAT_B_LEN];
    rakia_flat_baseline_config_default(fbc);
    fbc[RAKIA_FLAT_BC_MIN_SPREAD] = 0.5;
    CHECK_STATUS((rakia_status)rakia_flat_baseline_compute(ref, NULL, N, fbc, scratch, fb),
                 RAKIA_OK);
    CHECK(same_bits(fb[RAKIA_FLAT_B_CENTER], b.center));
    CHECK(same_bits(fb[RAKIA_FLAT_B_SPREAD], b.spread));
    CHECK(same_bits(fb[RAKIA_FLAT_B_N], (double)b.n));

    double z = 0.0;
    double zr = 0.0;
    CHECK_STATUS((rakia_status)rakia_flat_robust_z(70.0, fb, &z), RAKIA_OK);
    CHECK_STATUS(rakia_robust_z(70.0, &b, &zr), RAKIA_OK);
    CHECK(same_bits(z, zr));

    rakia_assess_config acfg;
    rakia_assess_config_default(&acfg);
    rakia_assessment a;
    CHECK_STATUS(rakia_assess(mon, NULL, N, &b, &acfg, z1, &a), RAKIA_OK);

    double fac[RAKIA_FLAT_AC_LEN];
    double fa[RAKIA_FLAT_A_LEN];
    rakia_flat_assess_config_default(fac);
    CHECK_STATUS((rakia_status)rakia_flat_assess(mon, NULL, N, fb, fac, z2, fa), RAKIA_OK);
    CHECK(memcmp(z1, z2, sizeof(z1)) == 0);
    CHECK(same_bits(fa[RAKIA_FLAT_A_LEVEL], (double)a.level));
    CHECK(same_bits(fa[RAKIA_FLAT_A_REASONS], (double)a.reasons));
    CHECK(same_bits(fa[RAKIA_FLAT_A_LATEST_VALUE], a.latest_value));
    CHECK(same_bits(fa[RAKIA_FLAT_A_LATEST_Z], a.latest_z));
    CHECK(same_bits(fa[RAKIA_FLAT_A_DEVIATION], a.deviation));
    CHECK(same_bits(fa[RAKIA_FLAT_A_LATEST_INDEX], (double)a.latest_index));
    CHECK(same_bits(fa[RAKIA_FLAT_A_N_USABLE], (double)a.n_usable));
    CHECK(same_bits(fa[RAKIA_FLAT_A_WINDOW_QUALITY], a.window_quality));
    const double *cu = fa + RAKIA_FLAT_A_CUSUM;
    CHECK(same_bits(cu[RAKIA_FLAT_CU_ALARM], (double)a.cusum.alarm));
    CHECK(same_bits(cu[RAKIA_FLAT_CU_DIRECTION], (double)a.cusum.direction));
    CHECK(same_bits(cu[RAKIA_FLAT_CU_ALARM_INDEX], (double)a.cusum.alarm_index));
    CHECK(same_bits(cu[RAKIA_FLAT_CU_ONSET_INDEX], (double)a.cusum.onset_index));
    CHECK(same_bits(cu[RAKIA_FLAT_CU_S_POS], a.cusum.s_pos));
    CHECK(same_bits(cu[RAKIA_FLAT_CU_S_NEG], a.cusum.s_neg));
    /* The step at index 40 is large enough that this series must alarm. */
    CHECK(a.cusum.alarm == 1 && a.cusum.direction == 1);

    /* Standalone CUSUM over the same residuals. */
    rakia_cusum_result cr;
    double fcr[RAKIA_FLAT_CU_LEN];
    CHECK_STATUS(rakia_cusum(z1, N, &acfg.cusum, &cr), RAKIA_OK);
    CHECK_STATUS((rakia_status)rakia_flat_cusum(z1, N, acfg.cusum.k, acfg.cusum.h, fcr), RAKIA_OK);
    CHECK(same_bits(fcr[RAKIA_FLAT_CU_ALARM_INDEX], (double)cr.alarm_index));
    CHECK(same_bits(fcr[RAKIA_FLAT_CU_N_USED], (double)cr.n_used));
    CHECK(same_bits(fcr[RAKIA_FLAT_CU_S_POS], cr.s_pos));
}

static void test_counts_rejected(void)
{
    double ref[N];
    double mon[N];
    double scratch[N];
    double fb[RAKIA_FLAT_B_LEN];
    double fbc[RAKIA_FLAT_BC_LEN];
    make_series(ref, mon);
    rakia_flat_baseline_config_default(fbc);

    const double bad[] = {14.5, -1.0, NAN, INFINITY, 1e300};
    const rakia_status want[] = {RAKIA_E_RANGE, RAKIA_E_RANGE, RAKIA_E_NONFINITE,
                                 RAKIA_E_NONFINITE, RAKIA_E_RANGE};
    for (size_t i = 0; i < sizeof(bad) / sizeof(bad[0]); ++i) {
        fbc[RAKIA_FLAT_BC_MIN_SAMPLES] = bad[i];
        CHECK_STATUS((rakia_status)rakia_flat_baseline_compute(ref, NULL, N, fbc, scratch, fb),
                     want[i]);
    }
    CHECK_STATUS((rakia_status)rakia_flat_baseline_compute(ref, NULL, N, NULL, scratch, fb),
                 RAKIA_E_NULL);

    double fac[RAKIA_FLAT_AC_LEN];
    double fa[RAKIA_FLAT_A_LEN];
    double z[N];
    const double base[RAKIA_FLAT_B_LEN] = {60.0, 2.0, 60.0};
    rakia_flat_assess_config_default(fac);
    fac[RAKIA_FLAT_AC_PERSISTENCE] = 2.25;
    CHECK_STATUS((rakia_status)rakia_flat_assess(mon, NULL, N, base, fac, z, fa), RAKIA_E_RANGE);
    rakia_flat_assess_config_default(fac);
    fac[RAKIA_FLAT_AC_CONFIRM_COUNT] = -3.0;
    CHECK_STATUS((rakia_status)rakia_flat_assess(mon, NULL, N, base, fac, z, fa), RAKIA_E_RANGE);
    const double bad_base[RAKIA_FLAT_B_LEN] = {60.0, 2.0, 0.5};
    rakia_flat_assess_config_default(fac);
    CHECK_STATUS((rakia_status)rakia_flat_assess(mon, NULL, N, bad_base, fac, z, fa),
                 RAKIA_E_RANGE);
    double zz = 0.0;
    CHECK_STATUS((rakia_status)rakia_flat_robust_z(1.0, bad_base, &zz), RAKIA_E_RANGE);
}

static void test_trend_matches(void)
{
    double t[40];
    double y[40];
    for (int i = 0; i < 40; ++i) {
        t[i] = (double)i;
        y[i] = 0.25 * (double)i + (double)((i * 7) % 5);
    }
    static double scratch[2048];
    const size_t need = rakia_trend_scratch_size(40);
    CHECK(need <= 2048);
    rakia_trend tr;
    double ft[RAKIA_FLAT_TR_LEN];
    CHECK_STATUS(rakia_trend_compute(t, y, 40, scratch, need, &tr), RAKIA_OK);
    CHECK_STATUS((rakia_status)rakia_flat_trend(t, y, 40, scratch, need, ft), RAKIA_OK);
    CHECK(same_bits(ft[RAKIA_FLAT_TR_SLOPE], tr.slope));
    CHECK(same_bits(ft[RAKIA_FLAT_TR_INTERCEPT], tr.intercept));
    CHECK(same_bits(ft[RAKIA_FLAT_TR_MK_S], tr.mk_s));
    CHECK(same_bits(ft[RAKIA_FLAT_TR_P_VALUE], tr.p_value));
    CHECK(same_bits(ft[RAKIA_FLAT_TR_N], 40.0));
    CHECK_STATUS((rakia_status)rakia_flat_trend(t, y, 40, scratch, need - 1, ft), RAKIA_E_BUFFER);
}

static void test_record_hash_matches(void)
{
    /* Same record as the golden chain in test_ledger.c. */
    uint8_t id[16];
    uint8_t subject[16];
    for (uint8_t i = 0; i < 16; ++i) {
        id[i] = i;
        subject[i] = (uint8_t)(16u + i);
    }
    const uint8_t genesis[RAKIA_HASH_SIZE] = {0};
    const int64_t ints[RAKIA_FLAT_R_LEN] = {INT64_C(1762387200000000), 1};
    uint8_t h[RAKIA_HASH_SIZE];
    CHECK_STATUS((rakia_status)rakia_flat_record_hash(id, subject, "heart_rate.resting", 62.5,
                                                      "/min", ints, RAKIA_METHOD_MEASURED,
                                                      RAKIA_PROVENANCE_SIMULATED, genesis, h),
                 RAKIA_OK);
    static const uint8_t golden[RAKIA_HASH_SIZE] = {
        0xe9, 0xe4, 0x05, 0x65, 0x74, 0x6a, 0x10, 0xe6, 0xb7, 0x82, 0x26,
        0x02, 0x84, 0xdd, 0x52, 0xfc, 0xea, 0xd9, 0xcc, 0x92, 0x33, 0xbb,
        0xb6, 0xc9, 0x93, 0x68, 0xbf, 0x25, 0x96, 0xcc, 0xa0, 0x3d};
    CHECK(memcmp(h, golden, RAKIA_HASH_SIZE) == 0);

    const int64_t zero_seq[RAKIA_FLAT_R_LEN] = {0, 0};
    CHECK_STATUS((rakia_status)rakia_flat_record_hash(id, subject, "spo2", 97.0, "%", zero_seq, 1,
                                                      1, genesis, h),
                 RAKIA_E_RANGE);
    CHECK_STATUS((rakia_status)rakia_flat_record_hash(id, subject, "spo2", 97.0, "%", ints, 256, 1,
                                                      genesis, h),
                 RAKIA_E_RANGE);
    CHECK_STATUS((rakia_status)rakia_flat_record_hash(id, subject, "Bad Code", 97.0, "%", ints, 1,
                                                      1, genesis, h),
                 RAKIA_E_RANGE);
    CHECK_STATUS((rakia_status)rakia_flat_record_hash(NULL, subject, "spo2", 97.0, "%", ints, 1,
                                                      1, genesis, h),
                 RAKIA_E_NULL);
}

int main(void)
{
    test_defaults();
    test_quality_matches();
    test_assess_matches();
    test_counts_rejected();
    test_trend_matches();
    test_record_hash_matches();
    return rk_report("test_flat");
}
