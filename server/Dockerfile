# syntax=docker/dockerfile:1
# SPDX-License-Identifier: Apache-2.0
#
# rakia-api container for Google Cloud Run (or any container host).
# Build from the repository root:
#   docker build -f server/Dockerfile -t rakia-api server
#
# The image holds no configuration and no secrets: every setting comes from
# environment variables at run time (see .env.example), secrets through the
# platform's secret manager. It defaults to production mode, in which the
# API reads no .env file and requires TLS (verify-full) to the database.

# Debian 13 (trixie) slim, pinned by digest; Dependabot proposes updates.
ARG DEBIAN=debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2

FROM ${DEBIAN} AS build
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates cmake g++ libpq-dev make \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY CMakeLists.txt ./
COPY cmake ./cmake
COPY src ./src
COPY tests ./tests
# Warnings are errors; the unit and HTTP tests must pass for the image to
# build. (The PostgreSQL tests skip without RAKIA_API_PG_TESTS.)
RUN cmake -S . -B build -DCMAKE_BUILD_TYPE=Release \
 && cmake --build build --parallel \
 && ctest --test-dir build --output-on-failure \
 && strip build/rakia-api

FROM ${DEBIAN}
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates libpq5 \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --uid 10001 --no-create-home --shell /usr/sbin/nologin rakia
COPY --from=build /src/build/rakia-api /usr/local/bin/rakia-api
USER 10001
WORKDIR /tmp
ENV RAKIA_ENV=production \
    RAKIA_API_HOST=0.0.0.0 \
    RAKIA_TRUSTED_PROXY_HOPS=1
# Cloud Run sets PORT (8080 by default); RAKIA_API_PORT overrides it.
EXPOSE 8080
# Liveness: GET /v1/health. Readiness: GET /v1/ready. Configure both as the
# platform's probes; the image adds no shell tools for a HEALTHCHECK.
ENTRYPOINT ["/usr/local/bin/rakia-api"]
