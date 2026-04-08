FROM alpine:3.19 AS base
RUN apk add --no-cache bash git curl
WORKDIR /workspace

FROM base AS lint
RUN apk add --no-cache shellcheck
COPY scripts/lint-entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

FROM base AS format
RUN apk add --no-cache shfmt
COPY scripts/format-entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

FROM base AS unit
RUN curl -fsSL https://git.io/shellspec | sh -s -- --yes --prefix /usr/local
ENTRYPOINT ["shellspec"]

FROM kcov/kcov:latest-alpine AS coverage
RUN apk add --no-cache bash git curl
WORKDIR /workspace
RUN curl -fsSL https://git.io/shellspec | sh -s -- --yes --prefix /usr/local
ENTRYPOINT ["shellspec", "--kcov"]

FROM base AS app
COPY app/dev.sh /usr/local/bin/dev
RUN chmod +x /usr/local/bin/dev
ENTRYPOINT ["dev"]
