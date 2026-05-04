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
  End

  It "builds and runs the $1 stage"
    When run run_dev "$1"
    The output should include "building stage $1"
    The output should include "running $1"
    The status should be success
  End
End
