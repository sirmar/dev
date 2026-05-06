#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

Describe 'ci'
  setup_ci_tool() {
    fixture_tool_repo
    GITHUB_OUTPUT="$(mktemp)"
    export GITHUB_OUTPUT
  }

  setup_ci_library() {
    fixture_library_repo
    GITHUB_OUTPUT="$(mktemp)"
    export GITHUB_OUTPUT
  }

  teardown_ci() {
    teardown
    rm -f "$GITHUB_OUTPUT"
    unset GITHUB_OUTPUT
  }

  Describe 'tool repo'
    Before 'setup_ci_tool'
    After 'teardown_ci'

    It 'emits build output with . as package'
      When run run_dev ci
      The status should be success
      The file "$GITHUB_OUTPUT" should be exist
      Assert [ "$(grep '^build=' "$GITHUB_OUTPUT" | cut -d= -f2-)" = '["."]' ]
    End

    It 'emits checks output with lint-dockerfile unconditionally and only known check stages'
      When run run_dev ci
      The status should be success
      Assert [ "$(grep '^checks=' "$GITHUB_OUTPUT" | cut -d= -f2-)" = '{"include":[{"package":".","target":"lint-dockerfile"},{"package":".","target":"lint"},{"package":".","target":"format"},{"package":".","target":"coverage"},{"package":".","target":"types"},{"package":".","target":"security"}]}' ]
    End

    It 'emits coverage output'
      When run run_dev ci
      The status should be success
      Assert [ "$(grep '^coverage=' "$GITHUB_OUTPUT" | cut -d= -f2-)" = '["."]' ]
    End

    It 'uses provided package name'
      When run run_dev ci myrepo
      The status should be success
      Assert [ "$(grep '^build=' "$GITHUB_OUTPUT" | cut -d= -f2-)" = '["myrepo"]' ]
      Assert [ "$(grep '^coverage=' "$GITHUB_OUTPUT" | cut -d= -f2-)" = '["myrepo"]' ]
    End

    It 'prints to stdout when GITHUB_OUTPUT is not set'
      When run bash -c "cd '$MOCK_DIR' && unset GITHUB_OUTPUT && bash '$DEV_SCRIPT' ci"
      The status should be success
      The output should include 'build='
      The output should include 'checks='
      The output should include 'coverage='
    End
  End

  Describe 'tool repo without coverage stage'
    setup_ci_tool_no_coverage() {
      setup_ci_tool
      grep -v ' AS coverage$' "$MOCK_DIR/Dockerfile" >"$MOCK_DIR/Dockerfile.tmp"
      mv "$MOCK_DIR/Dockerfile.tmp" "$MOCK_DIR/Dockerfile"
    }
    Before 'setup_ci_tool_no_coverage'
    After 'teardown_ci'

    It 'includes unit in checks when no coverage stage exists'
      When run run_dev ci
      The status should be success
      Assert grep -q '"target":"unit"' <(grep '^checks=' "$GITHUB_OUTPUT" | cut -d= -f2-)
    End
  End

  Describe 'library repo'
    Before 'setup_ci_library'
    After 'teardown_ci'

    It 'emits empty build output'
      When run run_dev ci
      The status should be success
      Assert [ "$(grep '^build=' "$GITHUB_OUTPUT" | cut -d= -f2-)" = '[]' ]
    End

    It 'emits coverage output when coverage stage exists'
      When run run_dev ci
      The status should be success
      Assert [ "$(grep '^coverage=' "$GITHUB_OUTPUT" | cut -d= -f2-)" = '["."]' ]
    End
  End
End
