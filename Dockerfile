FROM ghcr.io/sirmar/dev-bash:lint-v0.0.1 AS lint
FROM ghcr.io/sirmar/dev-bash:format-v0.0.1 AS format
FROM ghcr.io/sirmar/dev-bash:unit-v0.0.1 AS unit
FROM ghcr.io/sirmar/dev-bash:coverage-v0.0.1 AS coverage

FROM alpine:3.19 AS app
RUN apk add --no-cache bash=5.2.21-r0 git=2.43.7-r0 curl=8.14.1-r2
WORKDIR /workspace
COPY app/dev.sh /usr/local/bin/dev
RUN chmod +x /usr/local/bin/dev
ENTRYPOINT ["dev"]
