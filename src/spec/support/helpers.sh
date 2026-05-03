#!/usr/bin/env bash
# shellcheck shell=bash

DEV_SCRIPT="${SHELLSPEC_PROJECT_ROOT}/src/app/dev.sh"

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

run_dev() {
    (cd "$MOCK_DIR" && bash "$DEV_SCRIPT" "$@")
}

write_dev_config() {
    local dir="$1" name="$2" type="$3"
    shift 3
    printf 'DEV_NAME=%s\nDEV_REPO_TYPE=%s\n' "$name" "$type" >"$dir/.dev"
    for extra in "$@"; do
        printf '%s\n' "$extra" >>"$dir/.dev"
    done
}

teardown_mock_docker() {
    rm -rf "$MOCK_DIR"
}

# ---------------------------------------------------------------------------
# Git repo mock (for release/tag operations)
# ---------------------------------------------------------------------------

setup_mock_git_repo() {
    MOCK_DIR="$(mktemp -d)"
    git init -q "$MOCK_DIR"
    git -C "$MOCK_DIR" config user.email 'test@test.com'
    git -C "$MOCK_DIR" config user.name 'Test'
    write_dev_config "$MOCK_DIR" dev service
    cp "$DEV_SCRIPT" "$MOCK_DIR/dev.sh"
    git -C "$MOCK_DIR" add .
    git -C "$MOCK_DIR" commit -q -m 'init'
    export MOCK_DIR
}

teardown_mock_git_repo() {
    rm -rf "$MOCK_DIR"
}
