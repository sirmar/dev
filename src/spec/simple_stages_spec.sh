#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

Describe 'simple stages'
  Before 'fixture_service_repo'
  After 'teardown'

  Parameters
    types
    security
    lock
    unit
    format
    lint
    coverage
    watch
  End

  It "builds and runs the $1 stage"
    When run run_dev "$1"
    The output should include "building stage $1"
    The output should include "running $1"
    The status should be success
  End
End

Describe 'missing stage'
  Parameters
    unit
    e2e
  End

  After 'teardown'

  It "prints info and skips $1 without error"
    fixture_service_repo_without_stage "$1"
    When run run_dev "$1"
    The output should include "no '$1' stage found in Dockerfile"
    The output should not include "running $1"
    The status should be success
  End
End

Describe 'file path forwarding'
  Before 'fixture_service_repo'
  After 'teardown'

  Parameters
    unit
    coverage
    lint
    format
  End

  It "forwards a single translated file path to docker via $1"
    When run run_dev "$1" src/tests/foo_test.py
    The output should include '/workspace/src/tests/foo_test.py'
    The status should be success
  End

  It "forwards multiple translated file paths to docker via $1"
    When run run_dev "$1" src/tests/a_test.py src/tests/b_test.py
    The output should include '/workspace/src/tests/a_test.py'
    The output should include '/workspace/src/tests/b_test.py'
    The status should be success
  End
End
