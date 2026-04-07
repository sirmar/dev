#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/spec/support/helpers.sh"

Describe 'lint when lint stage is missing from Dockerfile'
  setup_lint_no_stage() { setup_mock_docker_without_stage lint; }
  teardown_lint_no_stage() { teardown_mock_docker; }
  Before 'setup_lint_no_stage'
  After 'teardown_lint_no_stage'

  It 'prints info and skips without error'
    When run run_dev lint
    The output should include "no 'lint' stage found in Dockerfile"
    The output should not include 'running lint'
    The status should be success
  End
End

Describe 'lint'
  Before 'setup_mock_docker'
  After 'teardown_mock_docker'

  It 'lints all files when no target given'
    When run run_dev lint
    The output should include 'building stage lint'
    The output should include 'running lint'
    The status should be success
  End

  It 'lints a specific file when target given'
    When run run_dev lint dev.sh
    The output should include 'building stage lint'
    The output should include 'running lint on dev.sh'
    The status should be success
  End
End

Describe 'lint --claude passes'
  setup_lint_claude_pass() { setup_claude_pass; }
  Before 'setup_lint_claude_pass'
  After 'teardown_mock_docker'

  It 'exits 0 and produces no stderr'
    When run bash -c "cd '$MOCK_DIR' && echo '{}' | bash '$DEV_SCRIPT' lint --claude"
    The status should be success
    The output should include 'building stage lint'
    The output should include 'running lint'
    The stderr should equal ''
  End
End

Describe 'lint --claude fails'
  setup_lint_claude_fail() { setup_claude_fail 'lint error'; }
  Before 'setup_lint_claude_fail'
  After 'teardown_mock_docker'

  It 'exits non-zero and writes lint output to stderr'
    When run bash -c "cd '$MOCK_DIR' && echo '{}' | bash '$DEV_SCRIPT' lint --claude"
    The status should be failure
    The output should include 'building stage lint'
    The output should include 'running lint'
    The stderr should include 'lint error'
  End
End

Describe 'lint --claude tails long output'
  setup_lint_claude_tail() { setup_claude_tail; }
  Before 'setup_lint_claude_tail'
  After 'teardown_mock_docker'

  It 'only shows last 20 lines on stderr'
    When run bash -c "cd '$MOCK_DIR' && echo '{}' | bash '$DEV_SCRIPT' lint --claude"
    The status should be failure
    The output should include 'building stage lint'
    The output should include 'running lint'
    The stderr should include 'error 30'
    The stderr should not include 'error 10'
  End
End
