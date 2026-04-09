FROM ghcr.io/sirmar/dev-bash:v0.0.1 AS base

FROM base AS lint
ENTRYPOINT ["/usr/local/bin/lint-entrypoint.sh"]

FROM base AS format
ENTRYPOINT ["/usr/local/bin/format-entrypoint.sh"]

FROM base AS unit
ENTRYPOINT ["shellspec"]

FROM kcov/kcov:latest-alpine AS coverage
RUN apk add --no-cache bash=5.2.26-r0 git=2.45.4-r0 curl=8.14.1-r2
WORKDIR /workspace
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://git.io/shellspec | sh -s -- --yes --prefix /usr/local
ENTRYPOINT ["shellspec", "--kcov"]

FROM alpine:3.19 AS app
RUN apk add --no-cache bash=5.2.21-r0 git=2.43.7-r0 curl=8.14.1-r2
WORKDIR /workspace
COPY app/dev.sh /usr/local/bin/dev
RUN chmod +x /usr/local/bin/dev
ENTRYPOINT ["dev"]
