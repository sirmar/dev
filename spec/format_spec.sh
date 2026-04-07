#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/spec/support/helpers.sh"

Describe 'format when format stage is missing from Dockerfile'
  setup_format_no_stage() { setup_mock_docker_without_stage format; }
  teardown_format_no_stage() { teardown_mock_docker; }
  Before 'setup_format_no_stage'
  After 'teardown_format_no_stage'

  It 'prints info and skips without error'
    When run run_dev format
    The output should include "no 'format' stage found in Dockerfile"
    The output should not include 'running format'
    The status should be success
  End
End

Describe 'format'
  Before 'setup_mock_docker'
  After 'teardown_mock_docker'

  It 'formats all files when no target given'
    When run run_dev format
    The output should include 'building stage format'
    The output should include 'running format'
    The status should be success
  End

  It 'formats a specific file when target given'
    When run run_dev format dev.sh
    The output should include 'building stage format'
    The output should include 'running format on dev.sh'
    The status should be success
  End
End

Describe 'format --claude passes'
  setup_format_claude_pass() { setup_claude_pass; }
  Before 'setup_format_claude_pass'
  After 'teardown_mock_docker'

  It 'exits 0 and suppresses output'
    When run bash -c "cd '$MOCK_DIR' && echo '{}' | bash '$DEV_SCRIPT' format --claude"
    The status should be success
    The output should include 'building stage format'
    The output should include 'running format on dev.sh'
    The stderr should equal ''
  End
End

Describe 'format --claude fails'
  setup_format_claude_fail() { setup_claude_fail 'format error'; }
  Before 'setup_format_claude_fail'
  After 'teardown_mock_docker'

  It 'exits 0 and suppresses output even when format fails'
    When run bash -c "cd '$MOCK_DIR' && echo '{}' | bash '$DEV_SCRIPT' format --claude"
    The status should be success
    The output should include 'building stage format'
    The output should include 'running format'
    The stderr should equal ''
  End
End
