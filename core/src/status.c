/* SPDX-License-Identifier: Apache-2.0 */
#include "internal.h"

#define RK_STR2(x) #x
#define RK_STR(x) RK_STR2(x)

const char *rakia_version(void)
{
    return RK_STR(RAKIA_VERSION_MAJOR) "." RK_STR(RAKIA_VERSION_MINOR) "." RK_STR(
        RAKIA_VERSION_PATCH);
}

const char *rakia_status_str(rakia_status status)
{
    switch (status) {
    case RAKIA_OK: return "ok";
    case RAKIA_E_NULL: return "required pointer was NULL";
    case RAKIA_E_EMPTY: return "input is empty";
    case RAKIA_E_NONFINITE: return "input contains NaN or infinity";
    case RAKIA_E_RANGE: return "parameter or input out of range";
    case RAKIA_E_BUFFER: return "buffer too small";
    case RAKIA_E_INSUFFICIENT: return "not enough valid data";
    case RAKIA_E_SINGULAR: return "matrix is not symmetric positive definite";
    case RAKIA_E_DEGENERATE: return "spread is zero or invalid";
    }
    return "unknown status";
}
