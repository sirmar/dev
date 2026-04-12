FROM alpine:3.19
LABEL org.opencontainers.image.source=https://github.com/sirmar/dev
RUN apk add --no-cache bash=5.2.21-r0 git=2.43.7-r0 curl=8.14.1-r2 shellcheck=0.9.0-r4 shfmt=3.7.0-r7
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://git.io/shellspec | sh -s -- --yes --prefix /usr/local
WORKDIR /workspace
COPY scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*-entrypoint.sh
