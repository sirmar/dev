#!/usr/bin/env bash
# shellcheck shell=bash

_MOCK_DOCKERFILE='FROM scratch AS lint
FROM scratch AS format
FROM scratch AS unit
FROM scratch AS coverage
FROM scratch AS types
FROM scratch AS security
FROM scratch AS lock
FROM scratch AS watch
FROM scratch AS prod'

fixture_finish_docker() {
    printf '#!/bin/sh\necho "docker $*"\n' >"$MOCK_DIR/docker"
    chmod +x "$MOCK_DIR/docker"
    export PATH="$MOCK_DIR:$PATH"
}

fixture_service_repo() {
    MOCK_DIR="$(mktemp -d)"
    printf '%s\n' "$_MOCK_DOCKERFILE" >"$MOCK_DIR/Dockerfile"
    write_dev_config "$MOCK_DIR" dev service
    fixture_finish_docker
    export MOCK_DIR
}

fixture_service_repo_with_e2e() {
    fixture_service_repo
    printf 'FROM scratch AS e2e\n' >>"$MOCK_DIR/Dockerfile"
    touch "$MOCK_DIR/docker-compose.e2e.yml"
}

fixture_tool_repo() {
    MOCK_DIR="$(mktemp -d)"
    printf '%s\n' "$_MOCK_DOCKERFILE" >"$MOCK_DIR/Dockerfile"
    write_dev_config "$MOCK_DIR" dev tool
    fixture_finish_docker
    export MOCK_DIR
}

fixture_e2e_repo() {
    MOCK_DIR="$(mktemp -d)"
    printf '%s\n' "$_MOCK_DOCKERFILE" >"$MOCK_DIR/Dockerfile"
    write_dev_config "$MOCK_DIR" dev e2e "DEV_NETWORK=dev_network"
    touch "$MOCK_DIR/docker-compose.yml"
    fixture_finish_docker
    export MOCK_DIR
}

fixture_service_repo_without_stage() {
    local stage="$1"
    fixture_service_repo
    grep -v " AS ${stage}$" "$MOCK_DIR/Dockerfile" >"$MOCK_DIR/Dockerfile.tmp"
    mv "$MOCK_DIR/Dockerfile.tmp" "$MOCK_DIR/Dockerfile"
}
