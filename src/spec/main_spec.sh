#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317,SC1091

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"
DEV_SCRIPT="$DEV_ROOT/src/app/dev.sh"

. "$DEV_ROOT/src/spec/support/helpers.sh"

Describe 'completions'
  setup() { MOCK_DIR="$(mktemp -d)"; }
  teardown() { rm -rf "$MOCK_DIR"; }
  Before 'setup'
  After 'teardown'

  It 'lists base commands for image repos'
    write_dev_config "$MOCK_DIR" myapp image
    When run bash -c "cd '$MOCK_DIR' && bash '$DEV_SCRIPT' completions"
    The status should be success
    The output should include 'build'
    The output should include 'lint'
    The output should not include 'format'
    The output should not include 'watch'
  End

  It 'lists tool commands for tool repos'
    write_dev_config "$MOCK_DIR" myapp tool
    When run bash -c "cd '$MOCK_DIR' && bash '$DEV_SCRIPT' completions"
    The status should be success
    The output should include 'format'
    The output should include 'unit'
    The output should not include 'watch'
    The output should not include 'shell'
  End

  It 'lists all commands for service repos'
    write_dev_config "$MOCK_DIR" myapp service
    When run bash -c "cd '$MOCK_DIR' && bash '$DEV_SCRIPT' completions"
    The status should be success
    The output should include 'watch'
    The output should include 'db-shell'
  End

  It 'lists base commands when no .dev found'
    When run bash -c "cd /tmp && bash '$DEV_SCRIPT' completions"
    The status should be success
    The output should include 'build'
    The output should not include 'watch'
  End
End


Describe 'find_root'
  Before 'setup_mock_docker'
  After 'teardown_mock_docker'

  It 'finds .dev file from project root'
    When run run_dev help
    The status should be success
    The output should include 'USAGE'
  End

  It 'finds .dev file from a subdirectory'
    When run bash -c "mkdir -p '$MOCK_DIR/nested' && cd '$MOCK_DIR/nested' && bash '$DEV_SCRIPT' help"
    The status should be success
    The output should include 'USAGE'
  End

  It 'fails when no .dev file exists'
    When run bash -c "cd /tmp && bash '$DEV_SCRIPT' help"
    The status should be failure
    The stderr should include 'no .dev file found'
  End
End

Describe 'main dispatch'
  Before 'setup_mock_docker'
  After 'teardown_mock_docker'

  It "shows help for 'help' command"
    When run run_dev help
    The output should include 'USAGE'
    The output should include 'build'
    The output should include 'lint'
    The status should be success
  End

  It 'shows help for --help flag'
    When run run_dev --help
    The output should include 'USAGE'
    The status should be success
  End

  It 'shows help when no command given'
    When run run_dev
    The output should include 'USAGE'
    The status should be success
  End

  It 'exits with error for unknown command'
    When run run_dev notacommand
    The status should be failure
    The stderr should include 'unknown command'
    The output should include 'USAGE'
  End
End
