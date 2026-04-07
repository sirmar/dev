#!/usr/bin/env bash
# shellcheck shell=bash

DEV_SCRIPT="${SHELLSPEC_PROJECT_ROOT}/app/dev.sh"

run_dev() {
    (cd "$MOCK_DIR" && bash "$DEV_SCRIPT" "$@")
}

# ---------------------------------------------------------------------------
# Canonical mock project — all helpers build on this
# ---------------------------------------------------------------------------

_MOCK_DOCKERFILE='FROM scratch AS lint
FROM scratch AS format
FROM scratch AS unit
FROM scratch AS coverage
FROM scratch AS types
FROM scratch AS app'

_MOCK_DEV='DEV_NAME=dev
DEV_SERVICE=app'

_setup_mock_project() {
    MOCK_DIR="$(mktemp -d)"
    printf '%s\n' "$_MOCK_DOCKERFILE" >"$MOCK_DIR/Dockerfile"
    printf '%s\n' "$_MOCK_DEV" >"$MOCK_DIR/.dev"
    export MOCK_DIR
}

# ---------------------------------------------------------------------------
# Standard mock (all stages present, docker echoes its args)
# ---------------------------------------------------------------------------

_finish_mock_docker_setup() {
    printf '#!/bin/sh\necho "docker $*"\n' >"$MOCK_DIR/docker"
    chmod +x "$MOCK_DIR/docker"
    export PATH="$MOCK_DIR:$PATH"
}

setup_mock_docker() {
    _setup_mock_project
    _finish_mock_docker_setup
}

teardown_mock_docker() {
    rm -rf "$MOCK_DIR"
}

# ---------------------------------------------------------------------------
# Stage-specific mocks
# ---------------------------------------------------------------------------

setup_mock_docker_with_stage() {
    local stage="$1"
    _setup_mock_project
    printf 'FROM scratch AS %s\n' "$stage" >>"$MOCK_DIR/Dockerfile"
    _finish_mock_docker_setup
}

setup_mock_docker_without_stage() {
    local stage="$1"
    _setup_mock_project
    grep -v " AS ${stage}$" "$MOCK_DIR/Dockerfile" >"$MOCK_DIR/Dockerfile.tmp"
    mv "$MOCK_DIR/Dockerfile.tmp" "$MOCK_DIR/Dockerfile"
    _finish_mock_docker_setup
}

# ---------------------------------------------------------------------------
# Git repo mock (for release/tag operations)
# ---------------------------------------------------------------------------

setup_mock_git_repo() {
    MOCK_DIR="$(mktemp -d)"
    git init -q "$MOCK_DIR"
    git -C "$MOCK_DIR" config user.email 'test@test.com'
    git -C "$MOCK_DIR" config user.name 'Test'
    printf '%s\n' "$_MOCK_DEV" >"$MOCK_DIR/.dev"
    cp "$DEV_SCRIPT" "$MOCK_DIR/dev.sh"
    git -C "$MOCK_DIR" add .
    git -C "$MOCK_DIR" commit -q -m 'init'
    export MOCK_DIR
}

teardown_mock_git_repo() {
    rm -rf "$MOCK_DIR"
}

# ---------------------------------------------------------------------------
# Claude mode helpers
# ---------------------------------------------------------------------------

_setup_claude_base() {
    _setup_mock_project
    printf '#!/bin/sh\necho "dev.sh"\n' >"$MOCK_DIR/jq"
}

_write_claude_docker() {
    local non_build_body="$1"
    cat >"$MOCK_DIR/docker" <<EOF
#!/bin/sh
case "\$1" in
build) exit 0 ;;
*) ${non_build_body}; exit 1 ;;
esac
EOF
}

_finish_claude_setup() {
    chmod +x "$MOCK_DIR/jq" "$MOCK_DIR/docker"
    export PATH="$MOCK_DIR:$PATH"
}

setup_claude_pass() {
    _setup_claude_base
    printf '#!/bin/sh\nexit 0\n' >"$MOCK_DIR/docker"
    _finish_claude_setup
}

setup_claude_fail() {
    local error_msg="$1"
    _setup_claude_base
    _write_claude_docker "echo \"$error_msg\""
    _finish_claude_setup
}

setup_claude_tail() {
    _setup_claude_base
    # shellcheck disable=SC2016
    _write_claude_docker 'for i in $(seq 1 30); do echo "error $i"; done'
    _finish_claude_setup
}
