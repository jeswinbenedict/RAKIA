/* SPDX-License-Identifier: Apache-2.0
 *
 * Canonical record encoding, format v1 (all integers big-endian):
 *   "RAKIA/MEAS/1"            12 bytes  domain tag
 *   id                        16 bytes
 *   subject_id                16 bytes
 *   len(metric_code)           1 byte,  then the code bytes
 *   value                      8 bytes  IEEE 754 binary64 bits (-0 encoded as +0)
 *   len(unit)                  1 byte,  then the unit bytes
 *   observed_at_us             8 bytes  two's complement
 *   method                     1 byte
 *   provenance                 1 byte
 *   client_seq                 8 bytes
 *   prev_hash                 32 bytes
 * The record hash is SHA-256 over this encoding.
 */
#include <string.h>

#include "internal.h"

static const char rk_tag[] = "RAKIA/MEAS/1";
#define RK_TAG_LEN (sizeof(rk_tag) - 1u)

static int rk_valid_code(const char *s, size_t *len_out)
{
    size_t len = 0;
    for (; s[len] != '\0'; ++len) {
        if (len >= RAKIA_MAX_CODE_LEN) {
            return 0;
        }
        const char ch = s[len];
        const int ok = (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch == '_' ||
                       ch == '.';
        if (!ok) {
            return 0;
        }
    }
    *len_out = len;
    return len > 0;
}

static int rk_valid_unit(const char *s, size_t *len_out)
{
    size_t len = 0;
    for (; s[len] != '\0'; ++len) {
        if (len >= RAKIA_MAX_UNIT_LEN) {
            return 0;
        }
        const unsigned char ch = (unsigned char)s[len];
        if (ch < 0x21u || ch > 0x7Eu) {
            return 0; /* UCUM codes are printable ASCII without spaces */
        }
    }
    *len_out = len;
    return len > 0;
}

static uint8_t *rk_put_u64(uint8_t *p, uint64_t v)
{
    for (unsigned i = 0; i < 8; ++i) {
        p[i] = (uint8_t)(v >> (56u - 8u * i));
    }
    return p + 8;
}

rakia_status rakia_record_encode(const rakia_record *rec, uint8_t *buf, size_t cap,
                                 size_t *len_out)
{
    if (rec == NULL || buf == NULL || len_out == NULL || rec->metric_code == NULL ||
        rec->unit == NULL) {
        return RAKIA_E_NULL;
    }
    if (!rk_finite(rec->value)) {
        return RAKIA_E_NONFINITE;
    }
    size_t code_len = 0;
    size_t unit_len = 0;
    if (!rk_valid_code(rec->metric_code, &code_len) || !rk_valid_unit(rec->unit, &unit_len)) {
        return RAKIA_E_RANGE;
    }
    if (rec->method < RAKIA_METHOD_MEASURED || rec->method > RAKIA_METHOD_DERIVED ||
        rec->provenance < RAKIA_PROVENANCE_REAL || rec->provenance > RAKIA_PROVENANCE_SIMULATED ||
        rec->client_seq == 0) {
        return RAKIA_E_RANGE;
    }

    const size_t need = RK_TAG_LEN + 16 + 16 + 1 + code_len + 8 + 1 + unit_len + 8 + 1 + 1 +
                        8 + RAKIA_HASH_SIZE;
    if (cap < need) {
        return RAKIA_E_BUFFER;
    }

    uint8_t *p = buf;
    memcpy(p, rk_tag, RK_TAG_LEN);
    p += RK_TAG_LEN;
    memcpy(p, rec->id, 16);
    p += 16;
    memcpy(p, rec->subject_id, 16);
    p += 16;
    *p++ = (uint8_t)code_len;
    memcpy(p, rec->metric_code, code_len);
    p += code_len;

    double v = rec->value;
    if (v == 0.0) {
        v = 0.0; /* normalise -0 */
    }
    uint64_t bits = 0;
    memcpy(&bits, &v, sizeof(bits));
    p = rk_put_u64(p, bits);

    *p++ = (uint8_t)unit_len;
    memcpy(p, rec->unit, unit_len);
    p += unit_len;
    p = rk_put_u64(p, (uint64_t)rec->observed_at_us);
    *p++ = rec->method;
    *p++ = rec->provenance;
    p = rk_put_u64(p, rec->client_seq);
    memcpy(p, rec->prev_hash, RAKIA_HASH_SIZE);
    p += RAKIA_HASH_SIZE;

    *len_out = (size_t)(p - buf);
    return RAKIA_OK;
}

rakia_status rakia_record_hash(const rakia_record *rec, uint8_t out[RAKIA_HASH_SIZE])
{
    if (out == NULL) {
        return RAKIA_E_NULL;
    }
    uint8_t buf[RAKIA_RECORD_MAX_ENCODED];
    size_t len = 0;
    const rakia_status st = rakia_record_encode(rec, buf, sizeof(buf), &len);
    if (st != RAKIA_OK) {
        return st;
    }
    return rakia_sha256(buf, len, out);
}

rakia_status rakia_chain_verify(const rakia_record *records,
                                const uint8_t (*hashes)[RAKIA_HASH_SIZE], size_t n,
                                const uint8_t genesis[RAKIA_HASH_SIZE], size_t *first_bad)
{
    if (records == NULL || hashes == NULL || genesis == NULL) {
        return RAKIA_E_NULL;
    }
    if (n == 0) {
        return RAKIA_E_EMPTY;
    }
    for (size_t i = 0; i < n; ++i) {
        const uint8_t *expected_prev = (i == 0) ? genesis : hashes[i - 1];
        int ok = memcmp(records[i].prev_hash, expected_prev, RAKIA_HASH_SIZE) == 0;
        if (ok && i > 0) {
            ok = records[i].client_seq == records[i - 1].client_seq + 1u;
        }
        if (ok) {
            uint8_t h[RAKIA_HASH_SIZE];
            const rakia_status st = rakia_record_hash(&records[i], h);
            ok = (st == RAKIA_OK) && memcmp(h, hashes[i], RAKIA_HASH_SIZE) == 0;
        }
        if (!ok) {
            if (first_bad != NULL) {
                *first_bad = i;
            }
            return RAKIA_E_RANGE;
        }
    }
    return RAKIA_OK;
}
