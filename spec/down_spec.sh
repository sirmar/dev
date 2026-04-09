#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"
DEV_SCRIPT="$DEV_ROOT/app/dev.sh"

# shellcheck disable=SC1091
. "$DEV_ROOT/spec/support/helpers.sh"

Describe 'down'
  setup_env() {
    MOCK_DIR="$(mktemp -d)"
    export PATH="$MOCK_DIR:$PATH"
    PROJ_DIR="$(mktemp -d)"
    cp "$DEV_SCRIPT" "$PROJ_DIR/dev.sh"
    write_dev_config "$PROJ_DIR" myapp service
    printf 'services:\n  api:\n    image: test\n' >"$PROJ_DIR/docker-compose.yml"
    printf '#!/bin/sh\necho "docker $*"\n' >"$MOCK_DIR/docker"
    chmod +x "$MOCK_DIR/docker"
  }

  teardown_env() {
    rm -rf "$MOCK_DIR" "$PROJ_DIR"
  }

  Before 'setup_env'
  After 'teardown_env'

  It 'stops services with docker compose using DEV_NAME as project name'
    When run bash -c "cd '$PROJ_DIR' && bash dev.sh down"
    The output should include 'stopping services'
    The status should be success
  End

  It 'passes extra flags to docker compose down'
    When run bash -c "cd '$PROJ_DIR' && bash dev.sh down --volumes"
    The output should include 'down --volumes'
    The status should be success
  End
End
