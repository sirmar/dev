#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/spec/support/helpers.sh"

Describe 'e2e when e2e stage is missing from Dockerfile'
  setup_e2e_no_stage() { setup_mock_docker_without_stage e2e; }
  Before 'setup_e2e_no_stage'
  After 'teardown_mock_docker'

  It 'prints info and skips without error'
    When run run_dev e2e
    The output should include "no 'e2e' stage found in Dockerfile"
    The status should be success
  End
End

Describe 'e2e when docker-compose.e2e.yml is missing'
  setup_e2e_no_compose() { setup_mock_docker_with_stage e2e; }
  Before 'setup_e2e_no_compose'
  After 'teardown_mock_docker'

  It 'prints info and skips without error'
    When run run_dev e2e
    The output should include 'no docker-compose.e2e.yml found'
    The status should be success
  End
End

Describe 'e2e'
  Before 'setup_mock_e2e'
  After 'teardown_mock_docker'

  It 'builds the e2e stage'
    When run run_dev e2e
    The output should include 'building stage e2e'
    The status should be success
  End

  It 'runs tests via compose'
    When run run_dev e2e
    The output should include 'running e2e tests'
    The output should include 'compose'
    The output should include 'run'
    The output should include 'e2e'
    The status should be success
  End

  It 'tears down with volumes removed'
    When run run_dev e2e
    The output should include 'compose'
    The output should include 'down -v'
    The status should be success
  End
End

Describe 'e2e is not available for image repos'
  setup_e2e_image_repo() {
    setup_mock_e2e
    printf 'DEV_NAME=dev\nDEV_REPO_TYPE=image\n' >"$MOCK_DIR/.dev"
  }
  Before 'setup_e2e_image_repo'
  After 'teardown_mock_docker'

  It 'exits with error'
    When run run_dev e2e
    The status should be failure
    The stderr should include "'e2e' is not available for image repos"
  End
End
