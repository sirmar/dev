#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

Describe 'lock'
  Describe 'when lock stage is missing from Dockerfile'
    setup_lock_no_stage() { setup_mock_docker_without_stage lock; }
    teardown_lock_no_stage() { teardown_mock_docker; }
    Before 'setup_lock_no_stage'
    After 'teardown_lock_no_stage'

    It 'prints info and skips without error'
      When run run_dev lock
      The output should include "no 'lock' stage found in Dockerfile"
      The output should not include 'running lock'
      The status should be success
    End
  End

  Describe 'when lock stage exists in Dockerfile'
    Before 'setup_mock_docker'
    After 'teardown_mock_docker'

    It 'builds and runs the lock stage'
      When run run_dev lock
      The output should include 'building stage lock'
      The output should include 'running lock'
      The status should be success
    End
  End

  Describe 'lockfile copy-back'
    setup_lock_with_out() {
      setup_mock_docker
      mkdir -p "$MOCK_DIR/out"
    }
    Before 'setup_lock_with_out'
    After 'teardown_mock_docker'

    It 'copies pnpm-lock.yaml from out/ to root when present'
      echo 'lock-content' >"$MOCK_DIR/out/pnpm-lock.yaml"
      When run run_dev lock
      The output should include 'running lock'
      The path "$MOCK_DIR/pnpm-lock.yaml" should be exist
      The contents of file "$MOCK_DIR/pnpm-lock.yaml" should equal 'lock-content'
      The status should be success
    End

    It 'copies uv.lock from out/ to root when present'
      echo 'uv-lock-content' >"$MOCK_DIR/out/uv.lock"
      When run run_dev lock
      The output should include 'running lock'
      The path "$MOCK_DIR/uv.lock" should be exist
      The contents of file "$MOCK_DIR/uv.lock" should equal 'uv-lock-content'
      The status should be success
    End

    It 'succeeds without error when no lockfile is present in out/'
      When run run_dev lock
      The output should include 'running lock'
      The status should be success
    End
  End
End
