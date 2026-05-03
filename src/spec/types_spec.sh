#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

Describe 'types'
  Describe 'when types stage is missing from Dockerfile'
    setup_types_no_stage() { fixture_service_repo_without_stage types; }
    Before 'setup_types_no_stage'
    After 'teardown_mock_docker'

    It 'prints info and skips without error'
      When run run_dev types
      The output should include "no 'types' stage found in Dockerfile"
      The output should not include 'running types'
      The status should be success
    End
  End

  Describe 'when types stage exists in Dockerfile'
    Before 'fixture_service_repo'
    After 'teardown_mock_docker'

    It 'builds and runs the types stage'
      When run run_dev types
      The output should include 'building stage types'
      The output should include 'running types'
      The status should be success
    End
  End
End
