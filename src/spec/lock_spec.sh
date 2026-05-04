#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317



Describe 'lock'
  Describe 'lockfile copy-back'
    setup_lock_with_out() {
      fixture_service_repo
      mkdir -p "$MOCK_DIR/out"
    }
    Before 'setup_lock_with_out'
    After 'teardown'

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
