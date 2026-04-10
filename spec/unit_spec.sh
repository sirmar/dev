#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/spec/support/helpers.sh"

Describe 'unit when unit stage is missing from Dockerfile'
  setup_unit_no_stage() { setup_mock_docker_without_stage unit; }
  teardown_unit_no_stage() { teardown_mock_docker; }
  Before 'setup_unit_no_stage'
  After 'teardown_unit_no_stage'

  It 'prints info and skips without error'
    When run run_dev unit
    The output should include "no 'unit' stage found in Dockerfile"
    The output should not include 'running unit'
    The status should be success
  End
End

Describe 'unit'
  Before 'setup_mock_docker'
  After 'teardown_mock_docker'

  It 'runs unit tests'
    When run run_dev unit
    The output should include 'building stage unit'
    The output should include 'running unit'
    The output should include 'docker run'
    The status should be success
  End
End

