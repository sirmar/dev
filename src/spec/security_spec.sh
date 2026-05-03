#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

Describe 'security'
  Describe 'when security stage exists in Dockerfile'
    Before 'fixture_service_repo'
    After 'teardown'

    It 'builds and runs the security stage'
      When run run_dev security
      The output should include 'building stage security'
      The output should include 'running security'
      The status should be success
    End
  End
End
