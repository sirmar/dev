#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317



setup_check_no_stages() {
	fixture_service_repo
	printf '' >"$MOCK_DIR/Dockerfile"
}


setup_check_lint_and_format_passed() {
	fixture_service_repo
	mkdir -p "$MOCK_DIR/out"
	printf '{"passed":false,"stages":[{"name":"lint-dockerfile","passed":true},{"name":"format","passed":true},{"name":"lint","passed":false}]}\n' \
		>"$MOCK_DIR/out/check-result.json"
}

setup_check_all_stages_passed() {
	fixture_service_repo
	mkdir -p "$MOCK_DIR/out"
	printf '{"passed":true,"stages":[{"name":"lint-dockerfile","passed":true},{"name":"format","passed":true},{"name":"lint","passed":true},{"name":"types","passed":true},{"name":"security","passed":true},{"name":"unit","passed":true},{"name":"e2e","passed":true}]}\n' \
		>"$MOCK_DIR/out/check-result.json"
}

setup_check_lint_fails() {
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


Describe 'check'
  Describe 'when all stages are present'
    Before 'fixture_service_repo'
    After 'teardown'

    It 'runs lint-dockerfile, fmt, lint, types, security, unit, and e2e in order'
      When run run_dev check
      The output should include 'linting Dockerfile'
      The output should include 'running format'
      The output should include 'running lint'
      The output should include 'running types'
      The output should include 'running unit tests'
      The status should be success
    End

    It 'writes out/check-result.json with passed true when all stages pass'
      When run run_dev check
      The output should include 'linting Dockerfile'
      The status should be success
      The path "$MOCK_DIR/out/check-result.json" should be exist
      The contents of file "$MOCK_DIR/out/check-result.json" should include '"passed":true'
    End

    It 'writes stages array with unit and e2e instead of coverage in check-result.json'
      When run run_dev check
      The output should include 'linting Dockerfile'
      The status should be success
      The contents of file "$MOCK_DIR/out/check-result.json" should include '"name":"lint-dockerfile"'
      The contents of file "$MOCK_DIR/out/check-result.json" should include '"name":"format"'
      The contents of file "$MOCK_DIR/out/check-result.json" should include '"name":"lint"'
      The contents of file "$MOCK_DIR/out/check-result.json" should include '"name":"types"'
      The contents of file "$MOCK_DIR/out/check-result.json" should include '"name":"security"'
      The contents of file "$MOCK_DIR/out/check-result.json" should include '"name":"unit"'
      The contents of file "$MOCK_DIR/out/check-result.json" should include '"name":"e2e"'
      The contents of file "$MOCK_DIR/out/check-result.json" should not include '"name":"coverage"'
    End
  End

  Describe 'when no stages are present'
    Before 'setup_check_no_stages'
    After 'teardown'

    It 'lints Dockerfile, skips all other checks, and exits successfully'
      When run run_dev check
      The output should include 'linting Dockerfile'
      The output should include "no 'format' stage found in Dockerfile"
      The output should include "no 'lint' stage found in Dockerfile"
      The output should include "no 'types' stage found in Dockerfile"
      The output should include "no 'unit' stage found in Dockerfile"
      The status should be success
    End
  End

  Describe 'when docker-compose.e2e.yml is absent'
    Before 'fixture_service_repo'
    After 'teardown'

    It 'skips e2e stage silently and exits successfully'
      When run run_dev check
      The output should not include 'running e2e tests'
      The output should include 'running unit tests'
      The status should be success
    End
  End

  Describe 'when lint fails'
    Before 'setup_check_lint_fails'
    After 'teardown'

    It 'stops after lint and does not run types or coverage'
      When run run_dev check
      The output should include 'linting Dockerfile'
      The output should include 'running format'
      The output should include 'running lint'
      The output should not include 'running types'
      The output should not include 'running coverage'
      The status should be failure
    End

    It 'writes check-result.json with passed false and lint stage failed'
      When run run_dev check
      The output should include 'running lint'
      The status should be failure
      The contents of file "$MOCK_DIR/out/check-result.json" should include '"passed":false'
      The contents of file "$MOCK_DIR/out/check-result.json" should include '{"name":"lint","passed":false}'
    End
  End
End

Describe 'check CLAUDECODE=1 narrowing'
  After 'teardown'

  Describe 'when no result file exists'
    Before 'fixture_service_repo'

    It 'runs full check'
      When run bash -c "cd '$MOCK_DIR' && CLAUDECODE=1 bash '$DEV_SCRIPT' check"
      The output should include 'linting Dockerfile'
      The output should include 'running format'
      The output should include 'running lint'
      The output should include 'running types'
      The output should include 'running unit tests'
      The status should be success
    End
  End

  Describe 'when some stages passed in previous run'
    Before 'setup_check_lint_and_format_passed'

    It 'skips stages that passed and runs stages that did not'
      When run bash -c "cd '$MOCK_DIR' && CLAUDECODE=1 bash '$DEV_SCRIPT' check"
      The output should not include 'linting Dockerfile'
      The output should not include 'running format'
      The output should include 'running lint'
      The status should be success
    End
  End

  Describe 'when all stages passed in previous run'
    Before 'setup_check_all_stages_passed'

    It 'runs full check (scope reset)'
      When run bash -c "cd '$MOCK_DIR' && CLAUDECODE=1 bash '$DEV_SCRIPT' check"
      The output should include 'linting Dockerfile'
      The output should include 'running format'
      The output should include 'running lint'
      The output should include 'running types'
      The output should include 'running unit tests'
      The status should be success
    End
  End

  Describe 're-emit result JSON'
    Before 'fixture_service_repo'

    It 're-emits check-result.json as last stdout line'
      When run bash -c "cd '$MOCK_DIR' && CLAUDECODE=1 bash '$DEV_SCRIPT' check"
      The output should include '{"passed":true'
      The status should be success
    End
  End
End
