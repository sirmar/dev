# kcov does not publish versioned Alpine tags; latest-alpine is the only available target
FROM kcov/kcov:latest-alpine
LABEL org.opencontainers.image.source=https://github.com/sirmar/dev
RUN apk add --no-cache bash=5.2.26-r0 git=2.45.4-r0 curl=8.14.1-r2 jq=1.7.1-r0
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://git.io/shellspec | sh -s 0.28.1 --yes --prefix /usr/local
WORKDIR /workspace
COPY bash/scripts/coverage-entrypoint.sh /usr/local/bin/
COPY shared/scripts/entrypoint-helper.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/coverage-entrypoint.sh
