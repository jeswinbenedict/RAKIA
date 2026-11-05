/* SPDX-License-Identifier: Apache-2.0 */
#include "rk_test.h"

#define N 40

static const rakia_baseline kBaseline = {60.0, 2.0, 30}; /* resting HR: 60 +/- 2 bpm */

static void fill(double *v, double value)
{
    for (int i = 0; i < N; ++i) {
        v[i] = value + ((i % 2 == 0) ? 0.5 : -0.5); /* small, in-baseline noise */
    }
}

static void test_within_baseline(void)
{
    double v[N];
    double z[N];
    fill(v, 60.0);
    rakia_assess_config cfg;
    rakia_assess_config_default(&cfg);
    rakia_assessment a;
    CHECK_STATUS(rakia_assess(v, NULL, N, &kBaseline, &cfg, z, &a), RAKIA_OK);
    CHECK(a.level == RAKIA_LEVEL_WITHIN_BASELINE);
    CHECK(a.reasons == 0);
    CHECK(a.n_usable == N);
    CHECK(a.latest_index == N - 1);
    CHECK_NEAR(a.latest_z, (59.5 - 60.0) / 2.0, 1e-15);
}

static void test_single_spike_is_watch_not_act(void)
{
    double v[N];
    double z[N];
    fill(v, 60.0);
    v[N - 1] = 75.0; /* z = 7.5, but a single value is not confirmed */
    rakia_assess_config cfg;
    rakia_assess_config_default(&cfg);
    rakia_assessment a;
    CHECK_STATUS(rakia_assess(v, NULL, N, &kBaseline, &cfg, z, &a), RAKIA_OK);
    CHECK(a.level == RAKIA_LEVEL_WATCH);
    CHECK((a.reasons & RAKIA_REASON_POINT_DEVIATION) != 0);
    CHECK((a.reasons & RAKIA_REASON_CONFIRMED_EXTREME) == 0);
    CHECK((a.reasons & RAKIA_REASON_SUSTAINED_SHIFT) == 0); /* one value is not a shift */
    CHECK_NEAR(a.deviation, 15.0, 1e-12);
}

static void test_confirmed_extreme_is_act(void)
{
    double v[N];
    double z[N];
    fill(v, 60.0);
    v[N - 2] = 75.0;
    v[N - 1] = 76.0;
    rakia_assess_config cfg;
    rakia_assess_config_default(&cfg);
    rakia_assessment a;
    CHECK_STATUS(rakia_assess(v, NULL, N, &kBaseline, &cfg, z, &a), RAKIA_OK);
    CHECK(a.level == RAKIA_LEVEL_ACT);
    CHECK((a.reasons & RAKIA_REASON_CONFIRMED_EXTREME) != 0);
}

static void test_sustained_shift_onset_and_persistence(void)
{
    double v[N];
    double z[N];
    fill(v, 60.0);
    for (int i = 25; i < N; ++i) {
        v[i] = 65.0; /* +2.5 SD shift from index 25 */
    }
    rakia_assess_config cfg;
    rakia_assess_config_default(&cfg);
    rakia_assessment a;
    CHECK_STATUS(rakia_assess(v, NULL, N, &kBaseline, &cfg, z, &a), RAKIA_OK);
    CHECK(a.cusum.alarm == 1 && a.cusum.direction == 1);
    CHECK(a.cusum.onset_index == 25);
    CHECK(a.cusum.alarm_index == 29); /* 2, 4, 6, 8, 10 > h = 8 */
    CHECK(a.level == RAKIA_LEVEL_ACT);
    CHECK((a.reasons & RAKIA_REASON_SUSTAINED_SHIFT) != 0);
    CHECK((a.reasons & RAKIA_REASON_PERSISTENT_SHIFT) != 0);
}

static void test_shift_just_detected_is_watch(void)
{
    double v[30];
    double z[30];
    for (int i = 0; i < 30; ++i) {
        v[i] = (i < 25) ? 60.0 : 65.0;
    }
    rakia_assess_config cfg;
    rakia_assess_config_default(&cfg);
    rakia_assessment a;
    CHECK_STATUS(rakia_assess(v, NULL, 30, &kBaseline, &cfg, z, &a), RAKIA_OK);
    CHECK(a.cusum.alarm == 1 && a.cusum.alarm_index == 29);
    CHECK(a.level == RAKIA_LEVEL_WATCH); /* not yet persistent */
    CHECK((a.reasons & RAKIA_REASON_PERSISTENT_SHIFT) == 0);
}

static void test_reverted_shift_is_not_act(void)
{
    double v[N];
    double z[N];
    fill(v, 60.0);
    for (int i = 20; i < 25; ++i) {
        v[i] = 65.0; /* brief +2.5 SD episode: alarm at 24, then back to normal */
    }
    rakia_assess_config cfg;
    rakia_assess_config_default(&cfg);
    rakia_assessment a;
    CHECK_STATUS(rakia_assess(v, NULL, N, &kBaseline, &cfg, z, &a), RAKIA_OK);
    CHECK(a.cusum.alarm == 1 && a.cusum.onset_index == 20 && a.cusum.alarm_index == 24);
    CHECK(a.level == RAKIA_LEVEL_WATCH); /* episode is reported, but not ACT */
    CHECK((a.reasons & RAKIA_REASON_PERSISTENT_SHIFT) == 0);
}

static void test_quality_gate(void)
{
    double v[N];
    double q[N];
    double z[N];
    fill(v, 60.0);
    for (int i = 0; i < N; ++i) {
        q[i] = (i % 2 == 0) ? 1.0 : 0.0; /* half the samples unusable */
    }
    v[N - 2] = 90.0; /* extreme, but the window fails the quality gate */
    v[N - 4] = 90.0;
    rakia_assess_config cfg;
    rakia_assess_config_default(&cfg);
    rakia_assessment a;
    CHECK_STATUS(rakia_assess(v, q, N, &kBaseline, &cfg, z, &a), RAKIA_OK);
    CHECK(a.level == RAKIA_LEVEL_DATA_QUALITY);
    CHECK(a.reasons == RAKIA_REASON_LOW_QUALITY);
    CHECK(a.n_usable == N / 2);
    CHECK(a.latest_index == N - 2);
    CHECK(isnan(z[N - 1]));

    for (int i = 0; i < N; ++i) {
        q[i] = 0.0;
    }
    CHECK_STATUS(rakia_assess(v, q, N, &kBaseline, &cfg, z, &a), RAKIA_OK);
    CHECK(a.level == RAKIA_LEVEL_INSUFFICIENT_DATA);
    CHECK(a.reasons == RAKIA_REASON_NO_VALID_DATA);
    CHECK(isnan(a.latest_z));
}

static void test_invalid(void)
{
    double v[3] = {1, 2, 3};
    double z[3];
    rakia_assess_config cfg;
    rakia_assess_config_default(&cfg);
    rakia_assessment a;
    const rakia_baseline zero = {60.0, 0.0, 30};
    CHECK_STATUS(rakia_assess(v, NULL, 3, &zero, &cfg, z, &a), RAKIA_E_DEGENERATE);
    CHECK_STATUS(rakia_assess(v, NULL, 0, &kBaseline, &cfg, z, &a), RAKIA_E_EMPTY);
    CHECK_STATUS(rakia_assess(v, NULL, 3, &kBaseline, &cfg, v, &a), RAKIA_E_RANGE);
    CHECK_STATUS(rakia_assess(NULL, NULL, 3, &kBaseline, &cfg, z, &a), RAKIA_E_NULL);
    cfg.act_z = 1.0; /* below watch_z */
    CHECK_STATUS(rakia_assess(v, NULL, 3, &kBaseline, &cfg, z, &a), RAKIA_E_RANGE);
    rakia_assess_config_default(&cfg);
    cfg.confirm_count = 1;
    CHECK_STATUS(rakia_assess(v, NULL, 3, &kBaseline, &cfg, z, &a), RAKIA_E_RANGE);
    rakia_assess_config_default(&cfg);
    cfg.watch_z = NAN;
    CHECK_STATUS(rakia_assess(v, NULL, 3, &kBaseline, &cfg, z, &a), RAKIA_E_NONFINITE);
}

int main(void)
{
    test_within_baseline();
    test_single_spike_is_watch_not_act();
    test_confirmed_extreme_is_act();
    test_sustained_shift_onset_and_persistence();
    test_shift_just_detected_is_watch();
    test_reverted_shift_is_not_act();
    test_quality_gate();
    test_invalid();
    return rk_report("test_assess");
}
