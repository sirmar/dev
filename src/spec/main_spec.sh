#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317


Describe 'completions'
  setup() { MOCK_DIR="$(mktemp -d)"; }
  Before 'setup'
  After 'teardown'

  It 'returns exact set for image repos'
    write_dev_config "$MOCK_DIR" myapp image
    When run bash -c "cd '$MOCK_DIR' && bash '$DEV_SCRIPT' completions"
    The status should be success
    The output should equal 'init build lint lint-dockerfile login push release tag diagnose help'
  End

  It 'returns exact set for service repos'
    write_dev_config "$MOCK_DIR" myapp service
    When run bash -c "cd '$MOCK_DIR' && bash '$DEV_SCRIPT' completions"
    The status should be success
    The output should equal 'init build lint lint-dockerfile login push release tag diagnose help format unit e2e check ci coverage types security lock watch shell rebuild up down clean logs db-shell db-migrate'
  End

  It 'returns exact set for tool repos'
    write_dev_config "$MOCK_DIR" myapp tool
    When run bash -c "cd '$MOCK_DIR' && bash '$DEV_SCRIPT' completions"
    The status should be success
    The output should equal 'init build lint lint-dockerfile login push release tag diagnose help format unit e2e check ci coverage types security lock run'
  End

  It 'returns exact set for library repos'
    write_dev_config "$MOCK_DIR" myapp library
    When run bash -c "cd '$MOCK_DIR' && bash '$DEV_SCRIPT' completions"
    The status should be success
    The output should equal 'init build lint lint-dockerfile login push release tag diagnose help format unit check ci coverage types security lock'
  End

  It 'returns exact set for e2e repos'
    write_dev_config "$MOCK_DIR" myapp e2e
    When run bash -c "cd '$MOCK_DIR' && bash '$DEV_SCRIPT' completions"
    The status should be success
    The output should equal 'init build lint lint-dockerfile login push release tag diagnose help format check ci types security lock run'
  End

  It 'returns correct set from a subdirectory'
    write_dev_config "$MOCK_DIR" myapp tool
    When run bash -c "mkdir -p '$MOCK_DIR/nested/deep' && cd '$MOCK_DIR/nested/deep' && bash '$DEV_SCRIPT' completions"
    The status should be success
    The output should equal 'init build lint lint-dockerfile login push release tag diagnose help format unit e2e check ci coverage types security lock run'
  End

  It 'returns base set when no .dev found'
    When run bash -c "cd /tmp && bash '$DEV_SCRIPT' completions"
    The status should be success
    The output should equal 'init build lint lint-dockerfile login push release tag diagnose help'
  End

  Describe 'with DEV_SCRIPTS from user config'
    setup() {
      MOCK_DIR="$(mktemp -d)"
      PROJ_DIR="$(mktemp -d)"
      write_dev_config "$MOCK_DIR" myapp tool
      mkdir -p "$PROJ_DIR/dev"
      printf 'DEV_SCRIPTS=deploy:scripts/deploy.sh\n' >"$PROJ_DIR/dev/config"
    }
    Before 'setup'
    After 'teardown'

    It 'includes exec when DEV_SCRIPTS set in user config'
      When run bash -c "cd '$MOCK_DIR' && XDG_CONFIG_HOME='$PROJ_DIR' bash '$DEV_SCRIPT' completions"
      The status should be success
      The output should include 'exec'
    End
  End
End


Describe 'find_root'
  It 'fails when no .dev file exists'
    When run bash -c "cd /tmp && bash '$DEV_SCRIPT' help"
    The status should be failure
    The stderr should include 'no .dev file found'
  End
End


Describe 'main dispatch'
  Before 'fixture_service_repo'
  After 'teardown'

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
