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

  It 'returns exact set for image repos'
    write_dev_config "$MOCK_DIR" myapp image
    When run bash -c "cd '$MOCK_DIR' && bash '$DEV_SCRIPT' completions"
    The status should be success
    The output should equal 'init build lint lint-dockerfile login push release help'
  End

  It 'returns exact set for service repos'
    write_dev_config "$MOCK_DIR" myapp service
    When run bash -c "cd '$MOCK_DIR' && bash '$DEV_SCRIPT' completions"
    The status should be success
    The output should equal 'init build lint lint-dockerfile login push release help format unit e2e check ci coverage types security lock watch shell rebuild up down clean logs db-shell db-migrate'
  End

  It 'returns exact set for tool repos'
    write_dev_config "$MOCK_DIR" myapp tool
    When run bash -c "cd '$MOCK_DIR' && bash '$DEV_SCRIPT' completions"
    The status should be success
    The output should equal 'init build lint lint-dockerfile login push release help format unit e2e check ci coverage types security lock run'
  End

  It 'returns exact set for library repos'
    write_dev_config "$MOCK_DIR" myapp library
    When run bash -c "cd '$MOCK_DIR' && bash '$DEV_SCRIPT' completions"
    The status should be success
    The output should equal 'init build lint lint-dockerfile login push release help format unit check ci coverage types security lock'
  End

  It 'returns exact set for e2e repos'
    write_dev_config "$MOCK_DIR" myapp e2e
    When run bash -c "cd '$MOCK_DIR' && bash '$DEV_SCRIPT' completions"
    The status should be success
    The output should equal 'init build lint lint-dockerfile login push release help format check ci types security lock run'
  End

  It 'returns base set when no .dev found'
    When run bash -c "cd /tmp && bash '$DEV_SCRIPT' completions"
    The status should be success
    The output should equal 'init build lint lint-dockerfile login push release help'
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
