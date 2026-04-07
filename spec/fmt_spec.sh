#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/spec/support/helpers.sh"

Describe 'fmt when format stage is missing from Dockerfile'
  setup_fmt_no_stage() { setup_mock_docker_without_stage format; }
  teardown_fmt_no_stage() { teardown_mock_docker; }
  Before 'setup_fmt_no_stage'
  After 'teardown_fmt_no_stage'

  It 'prints info and skips without error'
    When run run_dev fmt
    The output should include "no 'format' stage found in Dockerfile"
    The output should not include 'running fmt'
    The status should be success
  End
End

Describe 'fmt'
  Before 'setup_mock_docker'
  After 'teardown_mock_docker'

  It 'formats all files when no target given'
    When run run_dev fmt
    The output should include 'building stage format'
    The output should include 'running fmt'
    The status should be success
  End

  It 'formats a specific file when target given'
    When run run_dev fmt dev.sh
    The output should include 'building stage format'
    The output should include 'running fmt on dev.sh'
    The status should be success
  End

  It "accepts 'format' as an alias"
    When run run_dev format
    The output should include 'building stage format'
    The output should include 'running fmt'
    The status should be success
  End
End

Describe 'fmt --claude passes'
  setup_fmt_claude_pass() { setup_claude_pass; }
  Before 'setup_fmt_claude_pass'
  After 'teardown_mock_docker'

  It 'exits 0 and suppresses output'
    When run bash -c "cd '$MOCK_DIR' && echo '{}' | bash '$DEV_SCRIPT' fmt --claude"
    The status should be success
    The output should include 'building stage format'
    The output should include 'running fmt on dev.sh'
    The stderr should equal ''
  End
End

Describe 'fmt --claude fails'
  setup_fmt_claude_fail() { setup_claude_fail 'fmt error'; }
  Before 'setup_fmt_claude_fail'
  After 'teardown_mock_docker'

  It 'exits 0 and suppresses output even when fmt fails'
    When run bash -c "cd '$MOCK_DIR' && echo '{}' | bash '$DEV_SCRIPT' fmt --claude"
    The status should be success
    The output should include 'building stage format'
    The output should include 'running fmt'
    The stderr should equal ''
  End
End
