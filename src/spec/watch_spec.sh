#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

Describe 'watch'
  Describe 'when watch stage is missing from Dockerfile'
    setup_watch_no_stage() { setup_mock_docker_without_stage watch; }
    Before 'setup_watch_no_stage'
    After 'teardown_mock_docker'

    It 'prints info and skips without error'
      When run run_dev watch
      The output should include "no 'watch' stage found in Dockerfile"
      The status should be success
    End
  End

  Describe 'when watch stage exists in Dockerfile'
    Before 'setup_mock_docker'
    After 'teardown_mock_docker'

    It 'builds and runs the watch stage'
      When run run_dev watch
      The output should include 'building stage watch'
      The output should include 'starting watch'
      The status should be success
    End

    It 'mounts the workspace volume'
      When run run_dev watch
      The output should include '/workspace'
      The status should be success
    End

    It 'exposes DEV_PORT when set'
      write_dev_config "$MOCK_DIR" dev service "DEV_PORT=8080"
      When run run_dev watch
      The output should include '-p 8080:8080'
      The status should be success
    End

    It 'does not expose a port when DEV_PORT is unset'
      When run run_dev watch
      The output should not include '-p '
      The status should be success
    End
  End
End
