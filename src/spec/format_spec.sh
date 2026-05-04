#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317



Describe 'format'
  Before 'fixture_service_repo'
  After 'teardown'

  It 'formats all files when no target given'
    When run run_dev format
    The output should include 'building stage format'
    The output should include 'running format'
    The status should be success
  End
End

