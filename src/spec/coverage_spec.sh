#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

Describe 'coverage when coverage stage is missing from Dockerfile'
  setup_coverage_no_stage() { setup_mock_docker_without_stage coverage; }
  teardown_coverage_no_stage() { teardown_mock_docker; }
  Before 'setup_coverage_no_stage'
  After 'teardown_coverage_no_stage'

  It 'prints info and skips without error'
    When run run_dev coverage
    The output should include "no 'coverage' stage found in Dockerfile"
    The output should not include 'running coverage'
    The status should be success
  End
End

Describe 'coverage'
  Before 'setup_mock_docker'
  After 'teardown_mock_docker'

  It 'builds coverage image and runs'
    When run run_dev coverage
    The output should include 'building stage coverage'
    The output should include 'running coverage'
    The status should be success
  End

  It 'copies .coverage file from container'
    When run run_dev coverage
    The output should include 'docker cp'
    The output should include '.coverage'
    The status should be success
  End
End

Describe 'coverage (with docker-compose.e2e.yml)'
  setup_coverage_compose() {
    setup_mock_docker
    touch "$MOCK_DIR/docker-compose.e2e.yml"
  }
  Before 'setup_coverage_compose'
  After 'teardown_mock_docker'

  It 'uses compose instead of docker run'
    When run run_dev coverage
    The output should include 'docker compose'
    The output should not include 'docker run'
    The status should be success
  End
End
