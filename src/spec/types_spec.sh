#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

Describe 'types'
Describe 'when types stage exists in Dockerfile'
    Before 'fixture_service_repo'
    After 'teardown'

    It 'builds and runs the types stage'
      When run run_dev types
      The output should include 'building stage types'
      The output should include 'running types'
      The status should be success
    End
  End
End
