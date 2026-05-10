FROM ghcr.io/sirmar/dev-bash:v0.0.4 AS base

FROM base AS lint
ENTRYPOINT ["/usr/local/bin/lint-entrypoint.sh"]

FROM base AS format
ENTRYPOINT ["/usr/local/bin/format-entrypoint.sh"]

FROM base AS unit
WORKDIR /workspace
COPY .shellspec ./
ENTRYPOINT ["/usr/local/bin/unit-entrypoint.sh"]

FROM ghcr.io/sirmar/dev-bash-coverage:v0.0.4 AS coverage
WORKDIR /workspace
COPY .shellspec ./
ENTRYPOINT ["/usr/local/bin/coverage-entrypoint.sh"]

FROM alpine:3.19 AS prod
LABEL org.opencontainers.image.source=https://github.com/sirmar/dev
RUN apk add --no-cache bash=5.2.21-r0 git=2.43.7-r0 curl=8.14.1-r2 jq=1.7.1-r0
WORKDIR /workspace
COPY src/app/dev.sh /usr/local/bin/dev
RUN chmod +x /usr/local/bin/dev
ENTRYPOINT ["dev"]
