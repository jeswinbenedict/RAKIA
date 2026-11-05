/* SPDX-License-Identifier: Apache-2.0
 * Golden values were produced by an independent Python reference of the
 * documented v1 encoding using hashlib (see docs/algorithms/LIBRAKIA.md). */
#include <string.h>

#include "rk_test.h"

static void to_hex(const uint8_t *b, size_t n, char *out)
{
    static const char digits[] = "0123456789abcdef";
    for (size_t i = 0; i < n; ++i) {
        out[2 * i] = digits[b[i] >> 4];
        out[2 * i + 1] = digits[b[i] & 0x0F];
    }
    out[2 * n] = '\0';
}

static int hash_hex_equals(const char *data, size_t len, const char *expected)
{
    uint8_t h[RAKIA_HASH_SIZE];
    char hex[2 * RAKIA_HASH_SIZE + 1];
    if (rakia_sha256(data, len, h) != RAKIA_OK) {
        return 0;
    }
    to_hex(h, RAKIA_HASH_SIZE, hex);
    return strcmp(hex, expected) == 0;
}

static void test_sha256_vectors(void)
{
    /* FIPS 180-4 / NIST CSRC example vectors. */
    CHECK(hash_hex_equals("", 0,
                          "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"));
    CHECK(hash_hex_equals("abc", 3,
                          "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"));
    const char *two_block = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
    CHECK(hash_hex_equals(two_block, strlen(two_block),
                          "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"));
    /* One million 'a' exercises many blocks. */
    static char million[1000000];
    memset(million, 'a', sizeof(million));
    CHECK(hash_hex_equals(million, sizeof(million),
                          "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0"));
    uint8_t h[RAKIA_HASH_SIZE];
    CHECK_STATUS(rakia_sha256(NULL, 1, h), RAKIA_E_NULL);
    CHECK_STATUS(rakia_sha256(NULL, 0, h), RAKIA_OK);
}

static rakia_record make_record(uint8_t id_base, double value, int64_t t_us, uint64_t seq,
                                const uint8_t prev[RAKIA_HASH_SIZE])
{
    rakia_record r;
    memset(&r, 0, sizeof(r));
    for (uint8_t i = 0; i < 16; ++i) {
        r.id[i] = (uint8_t)(id_base + i);
        r.subject_id[i] = (uint8_t)(16u + i);
    }
    r.metric_code = "heart_rate.resting";
    r.value = value;
    r.unit = "/min";
    r.observed_at_us = t_us;
    r.method = RAKIA_METHOD_MEASURED;
    r.provenance = RAKIA_PROVENANCE_SIMULATED;
    r.client_seq = seq;
    memcpy(r.prev_hash, prev, RAKIA_HASH_SIZE);
    return r;
}

static void test_golden_chain(void)
{
    const uint8_t genesis[RAKIA_HASH_SIZE] = {0};
    rakia_record recs[2];
    uint8_t hashes[2][RAKIA_HASH_SIZE];
    char hex[2 * RAKIA_HASH_SIZE + 1];

    recs[0] = make_record(0, 62.5, INT64_C(1762387200000000), 1, genesis);
    uint8_t buf[RAKIA_RECORD_MAX_ENCODED];
    size_t len = 0;
    CHECK_STATUS(rakia_record_encode(&recs[0], buf, sizeof(buf), &len), RAKIA_OK);
    CHECK(len == 126);
    CHECK_STATUS(rakia_record_hash(&recs[0], hashes[0]), RAKIA_OK);
    to_hex(hashes[0], RAKIA_HASH_SIZE, hex);
    CHECK(strcmp(hex, "e9e40565746a10e6b782260284dd52fcead9cc9233bbb6c99368bf2596cca03d") == 0);

    /* -0.0 must encode exactly like +0.0. */
    recs[1] = make_record(32, -0.0, INT64_C(1762473600000000), 2, hashes[0]);
    CHECK_STATUS(rakia_record_hash(&recs[1], hashes[1]), RAKIA_OK);
    to_hex(hashes[1], RAKIA_HASH_SIZE, hex);
    CHECK(strcmp(hex, "0a60fdb1d729fbbd7e6d13bae46a3fa8667b1d620e02507e8157b5ac970be39a") == 0);

    size_t bad = 99;
    CHECK_STATUS(rakia_chain_verify(recs, (const uint8_t(*)[RAKIA_HASH_SIZE])hashes, 2, genesis,
                                    &bad),
                 RAKIA_OK);

    /* Tampering with a value breaks verification at that record. */
    recs[1].value = 64.0;
    CHECK_STATUS(rakia_chain_verify(recs, (const uint8_t(*)[RAKIA_HASH_SIZE])hashes, 2, genesis,
                                    &bad),
                 RAKIA_E_RANGE);
    CHECK(bad == 1);
    recs[1].value = -0.0;

    /* A sequence gap is detected. */
    recs[1].client_seq = 3;
    CHECK_STATUS(rakia_chain_verify(recs, (const uint8_t(*)[RAKIA_HASH_SIZE])hashes, 2, genesis,
                                    &bad),
                 RAKIA_E_RANGE);
    CHECK(bad == 1);
    recs[1].client_seq = 2;

    /* A wrong genesis fails at record 0. */
    const uint8_t other[RAKIA_HASH_SIZE] = {1};
    CHECK_STATUS(rakia_chain_verify(recs, (const uint8_t(*)[RAKIA_HASH_SIZE])hashes, 2, other,
                                    &bad),
                 RAKIA_E_RANGE);
    CHECK(bad == 0);
}

static void test_encode_validation(void)
{
    const uint8_t genesis[RAKIA_HASH_SIZE] = {0};
    uint8_t buf[RAKIA_RECORD_MAX_ENCODED];
    size_t len = 0;
    rakia_record r = make_record(0, 1.0, 0, 1, genesis);

    r.metric_code = "Heart Rate"; /* uppercase and space not allowed */
    CHECK_STATUS(rakia_record_encode(&r, buf, sizeof(buf), &len), RAKIA_E_RANGE);
    r.metric_code = "";
    CHECK_STATUS(rakia_record_encode(&r, buf, sizeof(buf), &len), RAKIA_E_RANGE);
    r.metric_code = "a_very_long_metric_code_that_exceeds_the_sixty_four_byte_limit_xx";
    CHECK_STATUS(rakia_record_encode(&r, buf, sizeof(buf), &len), RAKIA_E_RANGE);
    r.metric_code = "spo2";
    r.unit = "beats per min";
    CHECK_STATUS(rakia_record_encode(&r, buf, sizeof(buf), &len), RAKIA_E_RANGE);
    r.unit = "%";
    r.value = NAN;
    CHECK_STATUS(rakia_record_encode(&r, buf, sizeof(buf), &len), RAKIA_E_NONFINITE);
    r.value = 97.0;
    r.method = 0;
    CHECK_STATUS(rakia_record_encode(&r, buf, sizeof(buf), &len), RAKIA_E_RANGE);
    r.method = RAKIA_METHOD_ESTIMATED;
    r.provenance = 9;
    CHECK_STATUS(rakia_record_encode(&r, buf, sizeof(buf), &len), RAKIA_E_RANGE);
    r.provenance = RAKIA_PROVENANCE_REAL;
    r.client_seq = 0;
    CHECK_STATUS(rakia_record_encode(&r, buf, sizeof(buf), &len), RAKIA_E_RANGE);
    r.client_seq = 1;
    CHECK_STATUS(rakia_record_encode(&r, buf, 10, &len), RAKIA_E_BUFFER);
    CHECK_STATUS(rakia_record_encode(&r, buf, sizeof(buf), &len), RAKIA_OK);
    r.unit = NULL;
    CHECK_STATUS(rakia_record_encode(&r, buf, sizeof(buf), &len), RAKIA_E_NULL);
}

int main(void)
{
    test_sha256_vectors();
    test_golden_chain();
    test_encode_validation();
    return rk_report("test_ledger");
}
