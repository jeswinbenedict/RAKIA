/* SPDX-License-Identifier: Apache-2.0
 * SHA-256 per FIPS 180-4, written for librakia. Used for record integrity
 * (tamper evidence), not for secrecy. */
#include <string.h>

#include "internal.h"

typedef struct rk_sha256 {
    uint32_t h[8];
    uint64_t total_len;
    uint8_t block[64];
    size_t block_len;
} rk_sha256;

static const uint32_t rk_k[64] = {
    0x428a2f98u, 0x71374491u, 0xb5c0fbcfu, 0xe9b5dba5u, 0x3956c25bu, 0x59f111f1u, 0x923f82a4u,
    0xab1c5ed5u, 0xd807aa98u, 0x12835b01u, 0x243185beu, 0x550c7dc3u, 0x72be5d74u, 0x80deb1feu,
    0x9bdc06a7u, 0xc19bf174u, 0xe49b69c1u, 0xefbe4786u, 0x0fc19dc6u, 0x240ca1ccu, 0x2de92c6fu,
    0x4a7484aau, 0x5cb0a9dcu, 0x76f988dau, 0x983e5152u, 0xa831c66du, 0xb00327c8u, 0xbf597fc7u,
    0xc6e00bf3u, 0xd5a79147u, 0x06ca6351u, 0x14292967u, 0x27b70a85u, 0x2e1b2138u, 0x4d2c6dfcu,
    0x53380d13u, 0x650a7354u, 0x766a0abbu, 0x81c2c92eu, 0x92722c85u, 0xa2bfe8a1u, 0xa81a664bu,
    0xc24b8b70u, 0xc76c51a3u, 0xd192e819u, 0xd6990624u, 0xf40e3585u, 0x106aa070u, 0x19a4c116u,
    0x1e376c08u, 0x2748774cu, 0x34b0bcb5u, 0x391c0cb3u, 0x4ed8aa4au, 0x5b9cca4fu, 0x682e6ff3u,
    0x748f82eeu, 0x78a5636fu, 0x84c87814u, 0x8cc70208u, 0x90befffau, 0xa4506cebu, 0xbef9a3f7u,
    0xc67178f2u};

static uint32_t rk_rotr(uint32_t x, unsigned n) { return (x >> n) | (x << (32u - n)); }

static void rk_compress(rk_sha256 *c, const uint8_t *p)
{
    uint32_t w[64];
    for (size_t i = 0; i < 16; ++i) {
        w[i] = ((uint32_t)p[4 * i] << 24) | ((uint32_t)p[4 * i + 1] << 16) |
               ((uint32_t)p[4 * i + 2] << 8) | (uint32_t)p[4 * i + 3];
    }
    for (unsigned i = 16; i < 64; ++i) {
        const uint32_t s0 = rk_rotr(w[i - 15], 7) ^ rk_rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
        const uint32_t s1 = rk_rotr(w[i - 2], 17) ^ rk_rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = w[i - 16] + s0 + w[i - 7] + s1;
    }
    uint32_t a = c->h[0], b = c->h[1], cc = c->h[2], d = c->h[3];
    uint32_t e = c->h[4], f = c->h[5], g = c->h[6], h = c->h[7];
    for (unsigned i = 0; i < 64; ++i) {
        const uint32_t s1 = rk_rotr(e, 6) ^ rk_rotr(e, 11) ^ rk_rotr(e, 25);
        const uint32_t ch = (e & f) ^ (~e & g);
        const uint32_t t1 = h + s1 + ch + rk_k[i] + w[i];
        const uint32_t s0 = rk_rotr(a, 2) ^ rk_rotr(a, 13) ^ rk_rotr(a, 22);
        const uint32_t maj = (a & b) ^ (a & cc) ^ (b & cc);
        const uint32_t t2 = s0 + maj;
        h = g;
        g = f;
        f = e;
        e = d + t1;
        d = cc;
        cc = b;
        b = a;
        a = t1 + t2;
    }
    c->h[0] += a;
    c->h[1] += b;
    c->h[2] += cc;
    c->h[3] += d;
    c->h[4] += e;
    c->h[5] += f;
    c->h[6] += g;
    c->h[7] += h;
}

static void rk_init(rk_sha256 *c)
{
    static const uint32_t iv[8] = {0x6a09e667u, 0xbb67ae85u, 0x3c6ef372u, 0xa54ff53au,
                                   0x510e527fu, 0x9b05688cu, 0x1f83d9abu, 0x5be0cd19u};
    memcpy(c->h, iv, sizeof(iv));
    c->total_len = 0;
    c->block_len = 0;
}

static void rk_update(rk_sha256 *c, const uint8_t *p, size_t len)
{
    c->total_len += (uint64_t)len;
    while (len > 0) {
        size_t take = 64 - c->block_len;
        if (take > len) {
            take = len;
        }
        memcpy(c->block + c->block_len, p, take);
        c->block_len += take;
        p += take;
        len -= take;
        if (c->block_len == 64) {
            rk_compress(c, c->block);
            c->block_len = 0;
        }
    }
}

static void rk_final(rk_sha256 *c, uint8_t out[RAKIA_HASH_SIZE])
{
    const uint64_t bits = c->total_len * 8u;
    c->block[c->block_len++] = 0x80u;
    if (c->block_len > 56) {
        memset(c->block + c->block_len, 0, 64 - c->block_len);
        rk_compress(c, c->block);
        c->block_len = 0;
    }
    memset(c->block + c->block_len, 0, 56 - c->block_len);
    for (unsigned i = 0; i < 8; ++i) {
        c->block[56 + i] = (uint8_t)(bits >> (56u - 8u * i));
    }
    rk_compress(c, c->block);
    for (size_t i = 0; i < 8; ++i) {
        out[4 * i] = (uint8_t)(c->h[i] >> 24);
        out[4 * i + 1] = (uint8_t)(c->h[i] >> 16);
        out[4 * i + 2] = (uint8_t)(c->h[i] >> 8);
        out[4 * i + 3] = (uint8_t)c->h[i];
    }
}

rakia_status rakia_sha256(const void *data, size_t len, uint8_t out[RAKIA_HASH_SIZE])
{
    if (out == NULL || (data == NULL && len > 0)) {
        return RAKIA_E_NULL;
    }
    rk_sha256 c;
    rk_init(&c);
    if (len > 0) {
        rk_update(&c, (const uint8_t *)data, len);
    }
    rk_final(&c, out);
    return RAKIA_OK;
}
