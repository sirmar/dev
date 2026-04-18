#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

setup_check_no_stages() {
	_setup_mock_project
	printf '' >"$MOCK_DIR/Dockerfile"
	printf '#!/bin/sh\necho "docker $*"\n' >"$MOCK_DIR/docker"
	chmod +x "$MOCK_DIR/docker"
	export PATH="$MOCK_DIR:$PATH"
}

teardown_check_no_stages() { rm -rf "$MOCK_DIR"; }

setup_check_lint_fails() {
	_setup_mock_project
	cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
case "$*" in
run*--name*lint*) echo "lint failed"; exit 1 ;;
*) echo "docker $*"; exit 0 ;;
esac
EOF
	chmod +x "$MOCK_DIR/docker"
	export PATH="$MOCK_DIR:$PATH"
}

teardown_check_lint_fails() { rm -rf "$MOCK_DIR"; }

Describe 'check'
  Describe 'when all stages are present'
    Before 'setup_mock_docker'
    After 'teardown_mock_docker'

    It 'runs lint-dockerfile, fmt, lint, types, and coverage in order'
      When run run_dev check
      The output should include 'linting Dockerfile'
      The output should include 'running format'
      The output should include 'running lint'
      The output should include 'running types'
      The output should include 'running coverage'
      The status should be success
    End
  End

  Describe 'when no stages are present'
    Before 'setup_check_no_stages'
    After 'teardown_check_no_stages'

    It 'lints Dockerfile, skips all other checks, and exits successfully'
      When run run_dev check
      The output should include 'linting Dockerfile'
      The output should include "no 'format' stage found in Dockerfile"
      The output should include "no 'lint' stage found in Dockerfile"
      The output should include "no 'types' stage found in Dockerfile"
      The output should include "no 'coverage' stage found in Dockerfile"
      The status should be success
    End
  End

  Describe 'for e2e repos'
    Before 'setup_mock_e2e_repo'
    After 'teardown_mock_docker'

    It 'skips coverage and exits successfully'
      When run run_dev check
      The output should not include 'running coverage'
      The status should be success
    End
  End

  Describe 'when lint fails'
    Before 'setup_check_lint_fails'
    After 'teardown_check_lint_fails'

    It 'stops after lint and does not run types or coverage'
      When run run_dev check
      The output should include 'linting Dockerfile'
      The output should include 'running format'
      The output should include 'running lint'
      The output should not include 'running types'
      The output should not include 'running coverage'
      The status should be failure
    End
  End
End
