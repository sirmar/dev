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
