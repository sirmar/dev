#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"
DEV_SCRIPT="$DEV_ROOT/src/app/dev.sh"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

Describe 'logs'
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

  It 'shows logs with docker compose'
    When run bash -c "cd '$PROJ_DIR' && bash dev.sh logs"
    The output should include 'compose --project-name myapp'
    The output should include 'logs'
    The status should be success
  End

  It 'passes -f flag to docker compose logs'
    When run bash -c "cd '$PROJ_DIR' && bash dev.sh logs -f"
    The output should include 'logs -f'
    The status should be success
  End

  It 'passes --follow flag to docker compose logs'
    When run bash -c "cd '$PROJ_DIR' && bash dev.sh logs --follow"
    The output should include 'logs --follow'
    The status should be success
  End

  It 'passes service name to docker compose logs'
    When run bash -c "cd '$PROJ_DIR' && bash dev.sh logs api"
    The output should include 'logs api'
    The status should be success
  End

  It 'is not available for tool repos'
    write_dev_config "$PROJ_DIR" myapp tool
    When run bash -c "cd '$PROJ_DIR' && bash dev.sh logs"
    The status should be failure
    The stderr should include "'logs' is not available for tool repos"
  End
End
