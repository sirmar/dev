#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

Describe 'security'
  Describe 'when security stage is missing from Dockerfile'
    setup_security_no_stage() { setup_mock_docker_without_stage security; }
    teardown_security_no_stage() { teardown_mock_docker; }
    Before 'setup_security_no_stage'
    After 'teardown_security_no_stage'

    It 'prints info and skips without error'
      When run run_dev security
      The output should include "no 'security' stage found in Dockerfile"
      The output should not include 'running security'
      The status should be success
    End
  End

  Describe 'when security stage exists in Dockerfile'
    Before 'setup_mock_docker'
    After 'teardown_mock_docker'

    It 'builds and runs the security stage'
      When run run_dev security
      The output should include 'building stage security'
      The output should include 'running security'
      The status should be success
    End
  End
End
