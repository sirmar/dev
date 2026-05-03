#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

Describe 'coverage when coverage stage is missing from Dockerfile'
  setup_coverage_no_stage() { fixture_service_repo_without_stage coverage; }
  Before 'setup_coverage_no_stage'
  After 'teardown_mock_docker'

  It 'prints info and skips without error'
    When run run_dev coverage
    The output should include "no 'coverage' stage found in Dockerfile"
    The output should not include 'running coverage'
    The status should be success
  End
End

Describe 'coverage'
  Before 'fixture_service_repo'
  After 'teardown_mock_docker'

  It 'builds coverage image and runs'
    When run run_dev coverage
    The output should include 'building stage coverage'
    The output should include 'running coverage'
    The status should be success
  End

  It 'mounts out/ for coverage output'
    When run run_dev coverage
    The output should include '/workspace/out'
    The status should be success
  End

  It 'forwards a single translated file path to docker'
    When run run_dev coverage src/tests/foo_test.py
    The output should include '/workspace/src/tests/foo_test.py'
    The status should be success
  End

  It 'forwards multiple translated file paths to docker'
    When run run_dev coverage src/tests/a_test.py src/tests/b_test.py
    The output should include '/workspace/src/tests/a_test.py'
    The output should include '/workspace/src/tests/b_test.py'
    The status should be success
  End

  It 'runs full suite when no file args given'
    When run run_dev coverage
    The output should not include 'dev-coverage /workspace/src/'
    The status should be success
  End
End

Describe 'coverage (with docker-compose.e2e.yml)'
  setup_coverage_compose() {
    fixture_service_repo
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

  It 'forwards translated file path to docker compose run'
    When run run_dev coverage src/tests/foo_test.py
    The output should include '/workspace/src/tests/foo_test.py'
    The status should be success
  End

  It 'runs full suite when no file args given'
    When run run_dev coverage
    The output should not include 'run --rm coverage /workspace/'
    The status should be success
  End
End
