#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317



Describe 'e2e when docker-compose.e2e.yml is missing'
  setup_e2e_no_compose() {
    fixture_service_repo
    printf 'FROM scratch AS e2e\n' >>"$MOCK_DIR/Dockerfile"
  }
  Before 'setup_e2e_no_compose'
  After 'teardown'

  It 'prints info and skips without error'
    When run run_dev e2e
    The output should include 'no docker-compose.e2e.yml found'
    The status should be success
  End
End

Describe 'e2e'
  Before 'fixture_service_repo_with_e2e'
  After 'teardown'

  It 'builds the e2e stage'
    When run run_dev e2e
    The output should include 'building stage e2e'
    The status should be success
  End

  It 'runs tests via compose'
    When run run_dev e2e
    The output should include 'running e2e tests'
    The output should include 'compose'
    The output should include 'run'
    The output should include 'e2e'
    The status should be success
  End

  It 'cleans up before running'
    When run run_dev e2e
    The output should include 'docker-compose.e2e.yml'
    The output should include 'down -v'
    The status should be success
  End

  It 'does not touch main service compose'
    When run run_dev e2e
    The output should not include 'docker-compose.yml'
    The status should be success
  End

  It 'uses the e2e network compose file'
    When run run_dev e2e
    The output should include 'docker-compose.e2e-network.yml'
    The status should be success
  End

  It 'forwards translated file path to docker compose run'
    When run run_dev e2e src/tests/foo_test.py
    The output should include '/workspace/src/tests/foo_test.py'
    The status should be success
  End

  It 'runs full suite when no file args given'
    When run run_dev e2e
    The output should not include 'run --rm e2e /workspace/'
    The status should be success
  End
End

Describe 'e2e on failure'
  setup_e2e_failing() {
    fixture_service_repo_with_e2e
    cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
case "$*" in
  *" run --rm e2e") echo "docker $*"; exit 1 ;;
  *) echo "docker $*" ;;
esac
EOF
    chmod +x "$MOCK_DIR/docker"
  }
  Before 'setup_e2e_failing'
  After 'teardown'

  It 'dumps logs in CI'
    When run env CI=1 bash -c "cd '$MOCK_DIR' && bash '$DEV_ROOT/src/app/dev.sh' e2e"
    The output should include 'logs'
    The status should be failure
  End

  It 'does not dump logs locally'
    When run run_dev e2e
    The output should not include 'logs'
    The status should be failure
  End
End

setup_e2e_passes() {
  fixture_service_repo_with_e2e
  cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
mkdir -p "$MOCK_DIR/out"
case "$*" in
  *compose*run*e2e*)
    printf '{"passed":true,"failures":[]}\n' >"$MOCK_DIR/out/e2e-result.json"
    echo "docker $*"
    exit 0
    ;;
  *) echo "docker $*"; exit 0 ;;
esac
EOF
  chmod +x "$MOCK_DIR/docker"
}

Describe 'e2e result format'
  setup_e2e_some_fail() {
    fixture_service_repo_with_e2e
    cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
mkdir -p "$MOCK_DIR/out"
case "$*" in
  *compose*run*e2e*)
    printf '{"passed":false,"failures":[{"node_id":"src/tests/e2e/test_login.py::test_login_flow"}]}\n' >"$MOCK_DIR/out/e2e-result.json"
    echo "docker $*"
    exit 1
    ;;
  *) echo "docker $*"; exit 0 ;;
esac
EOF
    chmod +x "$MOCK_DIR/docker"
  }

  Describe 'when e2e passes'
    Before 'setup_e2e_passes'
    After 'teardown'

    It 'writes out/e2e-result.json with passed true and empty failures'
      When run run_dev e2e
      The output should include 'running e2e tests'
      The status should be success
      The path "$MOCK_DIR/out/e2e-result.json" should be exist
      The contents of file "$MOCK_DIR/out/e2e-result.json" should include '"passed":true'
      The contents of file "$MOCK_DIR/out/e2e-result.json" should include '"failures":[]'
    End
  End

  Describe 'when e2e fails'
    Before 'setup_e2e_some_fail'
    After 'teardown'

    It 'writes out/e2e-result.json with passed false and failure node_ids'
      When run run_dev e2e
      The output should include 'running e2e tests'
      The status should be failure
      The path "$MOCK_DIR/out/e2e-result.json" should be exist
      The contents of file "$MOCK_DIR/out/e2e-result.json" should include '"passed":false'
      The contents of file "$MOCK_DIR/out/e2e-result.json" should include 'test_login_flow'
    End
  End
End

Describe 'e2e --failed'
  After 'teardown'

  setup_e2e_narrowing() {
    fixture_service_repo_with_e2e
    cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
mkdir -p "$MOCK_DIR/out"
case "$*" in
  *compose*run*e2e*)
    printf '{"passed":false,"failures":[{"node_id":"src/tests/e2e/test_login.py::test_login_flow"}]}\n' >"$MOCK_DIR/out/e2e-result.json"
    echo "docker $*"
    exit 1
    ;;
  *) echo "docker $*"; exit 0 ;;
esac
EOF
    chmod +x "$MOCK_DIR/docker"
  }

  It 'exits with error when no result file exists'
    fixture_service_repo_with_e2e
    When run run_dev e2e --failed
    The stderr should include "no previous result found — run 'dev e2e' first"
    The status should be failure
  End

  It 'exits with error when last run had no failures'
    fixture_service_repo_with_e2e
    mkdir -p "$MOCK_DIR/out"
    printf '{"passed":true,"failures":[]}\n' >"$MOCK_DIR/out/e2e-result.json"
    When run run_dev e2e --failed
    The stderr should include "last run had no failures — nothing to re-run"
    The status should be failure
  End

  Describe 'when result file has failures'
    Before 'setup_e2e_narrowing'

    It 'passes node_ids as args to docker compose run'
      mkdir -p "$MOCK_DIR/out"
      printf '{"passed":false,"failures":[{"node_id":"src/tests/e2e/test_login.py::test_login_flow"}]}\n' >"$MOCK_DIR/out/e2e-result.json"
      When run run_dev e2e --failed
      The output should include 'test_login_flow'
      The status should be failure
    End
  End
End

Describe 'e2e re-emit result JSON'
  Before 'setup_e2e_passes'
  After 'teardown'

  It 're-emits e2e-result.json as last stdout line'
    When run run_dev e2e
    The output should include '{"passed":true,"failures":[]}'
    The status should be success
  End
End

Describe 'e2e skips on image repos'
  setup_e2e_image_repo() {
    fixture_service_repo_with_e2e
    write_dev_config "$MOCK_DIR" dev image
  }
  Before 'setup_e2e_image_repo'
  After 'teardown'

  It 'skips gracefully'
    When run run_dev e2e
    The status should be success
    The output should include 'skipping e2e'
  End
End
