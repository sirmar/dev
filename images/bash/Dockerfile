FROM alpine:3.19
RUN apk add --no-cache bash=5.2.21-r0 git=2.43.7-r0 curl=8.14.1-r2 shellcheck=0.9.0-r4 shfmt=3.7.0-r7
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://git.io/shellspec | sh -s -- --yes --prefix /usr/local
WORKDIR /workspace
COPY scripts/lint-entrypoint.sh /usr/local/bin/lint-entrypoint.sh
COPY scripts/format-entrypoint.sh /usr/local/bin/format-entrypoint.sh
RUN chmod +x /usr/local/bin/lint-entrypoint.sh /usr/local/bin/format-entrypoint.sh
