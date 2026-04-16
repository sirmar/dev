#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

run_dev_init() {
  local dir="$1"; shift
  (cd "$dir" && bash "$DEV_SCRIPT" init "$@")
}

Describe 'dev init'
  setup_init() { INIT_DIR="$(mktemp -d)"; export INIT_DIR; }
  teardown_init() { rm -rf "$INIT_DIR"; }
  Before 'setup_init'
  After 'teardown_init'

  It 'scaffolds a bash/tool project'
    When run run_dev_init "$INIT_DIR" tool bash myapp
    The status should be success
    The output should include 'myapp'
  End

  It 'logs written files'
    When run run_dev_init "$INIT_DIR" tool bash myapp
    The status should be success
    The output should include 'write .dev'
  End

  It 'creates .dev with correct name and repo type for bash/tool'
    run_dev_init "$INIT_DIR" tool bash myapp >/dev/null 2>&1
    When run cat "$INIT_DIR/.dev"
    The output should include 'DEV_NAME=myapp'
    The output should include 'DEV_REPO_TYPE=tool'
  End

  It 'substitutes DEV_NAME in Dockerfile for python/service'
    run_dev_init "$INIT_DIR" service python svc >/dev/null 2>&1
    When run cat "$INIT_DIR/Dockerfile"
    The output should include 'svc'
  End

  It 'scaffolds an image project without language'
    When run run_dev_init "$INIT_DIR" image myimg
    The status should be success
    The output should include 'myimg'
  End

  It 'creates .dev with repo type image for image projects'
    run_dev_init "$INIT_DIR" image myimg >/dev/null 2>&1
    When run cat "$INIT_DIR/.dev"
    The output should include 'DEV_REPO_TYPE=image'
  End

  It 'skips .dev if it already exists'
    touch "$INIT_DIR/.dev"
    When run run_dev_init "$INIT_DIR" tool bash myapp
    The status should be success
    The output should include 'skip .dev'
  End

  It 'fails with unknown language'
    When run run_dev_init "$INIT_DIR" tool ruby myapp
    The status should be failure
    The error should include 'unknown language'
  End

  It 'fails with unknown repo-type'
    When run run_dev_init "$INIT_DIR" library bash myapp
    The status should be failure
    The error should include 'unknown repo-type'
  End

  It 'fails with missing arguments'
    When run run_dev_init "$INIT_DIR"
    The status should be failure
    The error should include 'usage:'
  End
End
