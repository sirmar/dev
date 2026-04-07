#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"
DEV_SCRIPT="$DEV_ROOT/app/dev.sh"

# shellcheck disable=SC1091
. "$DEV_ROOT/spec/support/helpers.sh"

Describe 'fmt'
  Before 'setup_mock_docker'
  After 'teardown_mock_docker'

  It 'formats all files when no target given'
    When run bash "$DEV_SCRIPT" fmt
    The output should include 'building stage format'
    The output should include 'running fmt'
    The status should be success
  End

  It 'formats a specific file when target given'
    When run bash "$DEV_SCRIPT" fmt dev.sh
    The output should include 'building stage format'
    The output should include 'running fmt on dev.sh'
    The status should be success
  End

  It "accepts 'format' as an alias"
    When run bash "$DEV_SCRIPT" format
    The output should include 'building stage format'
    The output should include 'running fmt'
    The status should be success
  End
End

Describe 'fmt --claude passes'
  setup_fmt_claude_pass() { setup_claude_pass; }
  Before 'setup_fmt_claude_pass'
  After 'teardown_claude_pass'

  It 'exits 0 and suppresses output'
    When run bash -c "echo '{}' | bash '$DEV_SCRIPT' fmt --claude"
    The status should be success
    The output should include 'building stage format'
    The output should include 'running fmt on dev.sh'
    The stderr should equal ''
  End
End

Describe 'fmt --claude fails'
  setup_fmt_claude_fail() { setup_claude_fail 'fmt error'; }
  Before 'setup_fmt_claude_fail'
  After 'teardown_claude_fail'

  It 'exits 0 and suppresses output even when fmt fails'
    When run bash -c "echo '{}' | bash '$DEV_SCRIPT' fmt --claude"
    The status should be success
    The output should include 'building stage format'
    The output should include 'running fmt'
    The stderr should equal ''
  End
End
