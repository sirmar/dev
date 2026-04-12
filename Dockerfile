FROM ghcr.io/sirmar/dev-bash:v0.0.3 AS base

FROM base AS lint
ENTRYPOINT ["/usr/local/bin/lint-entrypoint.sh"]

FROM base AS format
ENTRYPOINT ["/usr/local/bin/format-entrypoint.sh"]

FROM base AS unit
WORKDIR /workspace
COPY .shellspec ./
ENTRYPOINT ["/usr/local/bin/unit-entrypoint.sh"]

FROM kcov/kcov:latest-alpine AS coverage
RUN apk add --no-cache bash=5.2.26-r0 git=2.45.4-r0 curl=8.14.1-r2
WORKDIR /workspace
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://git.io/shellspec | sh -s -- --yes --prefix /usr/local
COPY --from=base /usr/local/bin/coverage-entrypoint.sh /usr/local/bin/coverage-entrypoint.sh
COPY .shellspec ./
ENTRYPOINT ["/usr/local/bin/coverage-entrypoint.sh"]

FROM alpine:3.19 AS prod
LABEL org.opencontainers.image.source=https://github.com/sirmar/dev
RUN apk add --no-cache bash=5.2.21-r0 git=2.43.7-r0 curl=8.14.1-r2
WORKDIR /workspace
COPY src/app/dev.sh /usr/local/bin/dev
RUN chmod +x /usr/local/bin/dev
ENTRYPOINT ["dev"]
