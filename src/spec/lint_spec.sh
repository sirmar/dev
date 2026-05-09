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

Describe 'lint result format'
  setup_lint_fails() {
    fixture_service_repo
    cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
case "$*" in
  run*--name*lint*) echo "lint failed"; exit 1 ;;
  *) echo "docker $*"; exit 0 ;;
esac
EOF
    chmod +x "$MOCK_DIR/docker"
  }

  Describe 'when lint passes'
    Before 'fixture_service_repo'
    After 'teardown'

    It 'writes out/lint-result.json with passed true and empty failures'
      When run run_dev lint
      The output should include 'running lint'
      The status should be success
      The path "$MOCK_DIR/out/lint-result.json" should be exist
      The contents of file "$MOCK_DIR/out/lint-result.json" should include '"passed":true'
      The contents of file "$MOCK_DIR/out/lint-result.json" should include '"failures":[]'
    End
  End

  Describe 'when lint fails'
    Before 'setup_lint_fails'
    After 'teardown'

    It 'writes out/lint-result.json with passed false and empty failures'
      When run run_dev lint
      The output should include 'running lint'
      The status should be failure
      The path "$MOCK_DIR/out/lint-result.json" should be exist
      The contents of file "$MOCK_DIR/out/lint-result.json" should include '"passed":false'
      The contents of file "$MOCK_DIR/out/lint-result.json" should include '"failures":[]'
    End
  End
End

Describe 'lint-dockerfile result format'
  Before 'fixture_service_repo'
  After 'teardown'

  It 'writes out/lint-dockerfile-result.json with passed true'
    When run run_dev lint-dockerfile
    The output should include 'linting Dockerfile'
    The status should be success
    The path "$MOCK_DIR/out/lint-dockerfile-result.json" should be exist
    The contents of file "$MOCK_DIR/out/lint-dockerfile-result.json" should include '"passed":true'
    The contents of file "$MOCK_DIR/out/lint-dockerfile-result.json" should include '"failures":[]'
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

