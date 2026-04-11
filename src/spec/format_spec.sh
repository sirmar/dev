#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

Describe 'format when format stage is missing from Dockerfile'
  setup_format_no_stage() { setup_mock_docker_without_stage format; }
  teardown_format_no_stage() { teardown_mock_docker; }
  Before 'setup_format_no_stage'
  After 'teardown_format_no_stage'

  It 'prints info and skips without error'
    When run run_dev format
    The output should include "no 'format' stage found in Dockerfile"
    The output should not include 'running format'
    The status should be success
  End
End

Describe 'format'
  Before 'setup_mock_docker'
  After 'teardown_mock_docker'

  It 'formats all files when no target given'
    When run run_dev format
    The output should include 'building stage format'
    The output should include 'running format'
    The status should be success
  End

  It 'formats a specific file when target given'
    When run run_dev format dev.sh
    The output should include 'building stage format'
    The output should include 'running format on dev.sh'
    The status should be success
  End
End

