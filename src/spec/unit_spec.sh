#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317



setup_unit_passes() {
	fixture_service_repo
	cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
mkdir -p "$MOCK_DIR/out"
case "$*" in
run*)
	printf '{"passed":true,"failures":[]}\n' >"$MOCK_DIR/out/unit-result.json"
	echo "docker $*"
	exit 0
	;;
*) echo "docker $*"; exit 0 ;;
esac
EOF
	chmod +x "$MOCK_DIR/docker"
}

setup_unit_some_fail() {
	fixture_service_repo
	cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
mkdir -p "$MOCK_DIR/out"
case "$*" in
run*)
	printf '{"passed":false,"failures":[{"node_id":"src/tests/unit/test_auth.py::test_login_invalid"}]}\n' >"$MOCK_DIR/out/unit-result.json"
	echo "docker $*"
	exit 1
	;;
*) echo "docker $*"; exit 0 ;;
esac
EOF
	chmod +x "$MOCK_DIR/docker"
}

setup_unit_all_fail() {
	fixture_service_repo
	cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
mkdir -p "$MOCK_DIR/out"
case "$*" in
run*)
	printf '{"passed":false,"failures":[{"node_id":"src/tests/unit/test_auth.py::test_login_invalid"},{"node_id":"src/tests/unit/test_auth.py::test_signup_missing_field"}]}\n' >"$MOCK_DIR/out/unit-result.json"
	echo "docker $*"
	exit 1
	;;
*) echo "docker $*"; exit 0 ;;
esac
EOF
	chmod +x "$MOCK_DIR/docker"
}


setup_unit_parent_context_with_failures() {
	fixture_service_repo
	printf 'DEV_CONTEXT=..\n' >>"$MOCK_DIR/.dev"
	mkdir -p "$MOCK_DIR/out"
	printf '{"passed":false,"failures":[{"node_id":"src/tests/unit/test_auth.py::test_login_invalid"}]}\n' >"$MOCK_DIR/out/unit-result.json"
	cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
case "$*" in
run*) echo "docker $*"; exit 1 ;;
*) echo "docker $*"; exit 0 ;;
esac
EOF
	chmod +x "$MOCK_DIR/docker"
}

Describe 'unit'
  Before 'fixture_service_repo'
  After 'teardown'

  It 'uses docker run'
    When run run_dev unit
    The output should include 'docker run'
    The status should be success
  End

  It 'runs full suite when no file args given'
    When run run_dev unit
    The output should not include 'dev-unit /workspace/src/'
    The status should be success
  End
End

Describe 'unit --failed'
  Before 'fixture_service_repo'
  After 'teardown'

  It 'exits with error when no result file exists'
    When run run_dev unit --failed
    The stderr should include "no previous result found — run 'dev unit' first"
    The status should be failure
  End

  It 'exits with error when last run had no failures'
    mkdir -p "$MOCK_DIR/out"
    printf '{"passed":true,"failures":[]}\n' >"$MOCK_DIR/out/unit-result.json"
    When run run_dev unit --failed
    The stderr should include "last run had no failures — nothing to re-run"
    The status should be failure
  End
End

Describe 'unit CLAUDECODE=1 narrowing'
  After 'teardown'

  Describe 'when no result file exists'
    Before 'fixture_service_repo'

    It 'runs full suite'
      When run bash -c "cd '$MOCK_DIR' && CLAUDECODE=1 bash '$DEV_SCRIPT' unit"
      The output should include 'docker run'
      The output should not include 'test_login_invalid'
      The status should be success
    End
  End

  Describe 'when result file has failures'
    Before 'setup_unit_some_fail'

    It 'passes node_ids as args to docker run'
      mkdir -p "$MOCK_DIR/out"
      printf '{"passed":false,"failures":[{"node_id":"src/tests/unit/test_auth.py::test_login_invalid"}]}\n' >"$MOCK_DIR/out/unit-result.json"
      When run bash -c "cd '$MOCK_DIR' && CLAUDECODE=1 bash '$DEV_SCRIPT' unit"
      The output should include 'test_login_invalid'
      The status should be failure
    End
  End

  Describe 'when result file has no failures'
    Before 'setup_unit_passes'

    It 'runs full suite'
      mkdir -p "$MOCK_DIR/out"
      printf '{"passed":true,"failures":[]}\n' >"$MOCK_DIR/out/unit-result.json"
      When run bash -c "cd '$MOCK_DIR' && CLAUDECODE=1 bash '$DEV_SCRIPT' unit"
      The output should include 'docker run'
      The output should not include 'test_login_invalid'
      The status should be success
    End
  End

  Describe 're-emit result JSON'
    Before 'setup_unit_passes'

    It 're-emits unit-result.json as last stdout line'
      When run bash -c "cd '$MOCK_DIR' && CLAUDECODE=1 bash '$DEV_SCRIPT' unit"
      The output should include '{"passed":true,"failures":[]}'
      The status should be success
    End
  End
End

Describe 'unit CLAUDECODE=1 narrowing with DEV_CONTEXT=..'
  Before 'setup_unit_parent_context_with_failures'
  After 'teardown'

  It 'passes node_ids without DEV_CONTEXT path mangling'
    When run bash -c "cd '$MOCK_DIR' && CLAUDECODE=1 bash '$DEV_SCRIPT' unit"
    The output should include 'dev-unit src/tests/unit/test_auth.py::test_login_invalid'
    The status should be failure
  End
End

Describe 'unit result format'
  After 'teardown'

  Describe 'when all tests pass'
    Before 'setup_unit_passes'

    It 'writes out/unit-result.json with passed true and empty failures'
      When run run_dev unit
      The output should include 'docker run'
      The status should be success
      The path "$MOCK_DIR/out/unit-result.json" should be exist
      The contents of file "$MOCK_DIR/out/unit-result.json" should include '"passed":true'
      The contents of file "$MOCK_DIR/out/unit-result.json" should include '"failures":[]'
    End
  End

  Describe 'when some tests fail'
    Before 'setup_unit_some_fail'

    It 'writes out/unit-result.json with passed false and failure node_ids'
      When run run_dev unit
      The output should include 'docker run'
      The status should be failure
      The path "$MOCK_DIR/out/unit-result.json" should be exist
      The contents of file "$MOCK_DIR/out/unit-result.json" should include '"passed":false'
      The contents of file "$MOCK_DIR/out/unit-result.json" should include 'test_login_invalid'
    End
  End

  Describe 'when all tests fail'
    Before 'setup_unit_all_fail'

    It 'writes out/unit-result.json with all failure node_ids'
      When run run_dev unit
      The output should include 'docker run'
      The status should be failure
      The path "$MOCK_DIR/out/unit-result.json" should be exist
      The contents of file "$MOCK_DIR/out/unit-result.json" should include 'test_login_invalid'
      The contents of file "$MOCK_DIR/out/unit-result.json" should include 'test_signup_missing_field'
    End
  End
End
