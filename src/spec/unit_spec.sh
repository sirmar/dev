#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317



Describe 'unit'
  Before 'fixture_service_repo'
  After 'teardown'

  It 'uses docker run'
    When run run_dev unit
    The output should include 'docker run'
    The status should be success
  End

  It 'runs full suite when no file args given'
    When run run_dev unit
    The output should not include 'dev-unit /workspace/src/'
    The status should be success
  End
End

