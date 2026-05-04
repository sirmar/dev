#!/usr/bin/env bash
# shellcheck shell=bash

export DEV_ROOT="${SHELLSPEC_PROJECT_ROOT}"
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

teardown() {
    rm -rf "$MOCK_DIR" ${PROJ_DIR:+"$PROJ_DIR"}
    unset PROJ_DIR
}

