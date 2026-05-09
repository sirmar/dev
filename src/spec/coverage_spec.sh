#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317



Describe 'coverage'
  Before 'fixture_service_repo'
  After 'teardown'

  It 'mounts out/ for coverage output'
    When run run_dev coverage
    The output should include '/workspace/out'
    The status should be success
  End

  It 'runs full suite when no file args given'
    When run run_dev coverage
    The output should not include 'dev-coverage /workspace/src/'
    The status should be success
  End
End

Describe 'coverage result format'
  Before 'fixture_service_repo'
  After 'teardown'

  It 'writes out/coverage-result.json with passed true and empty failures'
    When run run_dev coverage
    The output should include 'running coverage'
    The status should be success
    The path "$MOCK_DIR/out/coverage-result.json" should be exist
    The contents of file "$MOCK_DIR/out/coverage-result.json" should include '"passed":true'
    The contents of file "$MOCK_DIR/out/coverage-result.json" should include '"failures":[]'
  End
End

Describe 'coverage (with docker-compose.e2e.yml)'
  setup_coverage_compose() {
    fixture_service_repo
    touch "$MOCK_DIR/docker-compose.e2e.yml"
  }
  Before 'setup_coverage_compose'
  After 'teardown'

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
