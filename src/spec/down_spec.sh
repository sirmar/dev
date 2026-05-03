#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

Describe 'down'
  Before 'fixture_service_proj'
  After 'teardown'

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
