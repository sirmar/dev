#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"
DEV_SCRIPT="$DEV_ROOT/src/app/dev.sh"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

Describe 'clean'
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

  It 'removes containers and volumes via compose down -v'
    When run bash -c "cd '$PROJ_DIR' && bash dev.sh clean"
    The output should include 'removing services and volumes'
    The output should include 'down -v'
    The status should be success
  End

  It 'does not run e2e compose when docker-compose.e2e.yml is absent'
    When run bash -c "cd '$PROJ_DIR' && bash dev.sh clean"
    The output should not include 'e2e-network'
    The status should be success
  End

  It 'also cleans e2e compose when docker-compose.e2e.yml is present'
    touch "$PROJ_DIR/docker-compose.e2e.yml"
    When run bash -c "cd '$PROJ_DIR' && bash dev.sh clean"
    The output should include 'docker-compose.e2e.yml'
    The output should include 'docker-compose.e2e-network.yml'
    The status should be success
  End
End
