#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317



Describe 'lint (image repo)'
  Before 'fixture_image_repo'
  After 'teardown'

  It 'does not run the lint stage'
    When run run_dev lint
    The output should not include 'building stage lint'
    The status should be success
  End
End

Describe 'lint-dockerfile'
  Before 'fixture_service_repo'
  After 'teardown'

  It 'runs hadolint on the Dockerfile'
    When run run_dev lint-dockerfile
    The output should include 'linting Dockerfile'
    The output should include 'hadolint'
    The status should be success
  End
End

Describe 'lint-dockerfile when Dockerfile is missing'
  setup_lint_dockerfile_no_file() {
    fixture_service_repo
    rm -f "$MOCK_DIR/Dockerfile"
  }
  Before 'setup_lint_dockerfile_no_file'
  After 'teardown'

  It 'prints info and skips without error'
    When run run_dev lint-dockerfile
    The output should include 'no Dockerfile found'
    The status should be success
  End
End

Describe 'lint'
  Before 'fixture_service_repo'
  After 'teardown'

  It 'lints all files when no target given'
    When run run_dev lint
    The output should include 'building stage lint'
    The output should include 'running lint'
    The status should be success
  End

  It 'lints a specific file when target given'
    When run run_dev lint dev.sh
    The output should include 'building stage lint'
    The output should include 'running lint in dev.sh'
    The status should be success
  End
End

