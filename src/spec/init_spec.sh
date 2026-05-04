#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317



run_dev_init() {
  local dir="$1"; shift
  (cd "$dir" && bash "$DEV_SCRIPT" init "$@")
}

Describe 'dev init'
  Before 'fixture_empty_dir'
  After 'teardown'

  It 'scaffolds a bash/tool project'
    When run run_dev_init "$PROJ_DIR" tool bash myapp
    The status should be success
    The output should include 'myapp'
  End

  It 'logs written files'
    When run run_dev_init "$PROJ_DIR" tool bash myapp
    The status should be success
    The output should include 'write .dev'
  End

  It 'creates .dev with correct name and repo type for bash/tool'
    run_dev_init "$PROJ_DIR" tool bash myapp >/dev/null 2>&1
    When run cat "$PROJ_DIR/.dev"
    The output should include 'DEV_NAME=myapp'
    The output should include 'DEV_REPO_TYPE=tool'
  End

  It 'substitutes DEV_NAME in Dockerfile for python/service'
    run_dev_init "$PROJ_DIR" service python svc >/dev/null 2>&1
    When run cat "$PROJ_DIR/Dockerfile"
    The output should include 'svc'
  End

  It 'scaffolds an image project without language'
    When run run_dev_init "$PROJ_DIR" image myimg
    The status should be success
    The output should include 'myimg'
  End

  It 'creates .dev with repo type image for image projects'
    run_dev_init "$PROJ_DIR" image myimg >/dev/null 2>&1
    When run cat "$PROJ_DIR/.dev"
    The output should include 'DEV_REPO_TYPE=image'
  End

  It 'skips .dev if it already exists'
    touch "$PROJ_DIR/.dev"
    When run run_dev_init "$PROJ_DIR" tool bash myapp
    The status should be success
    The output should include 'skip .dev'
  End

  It 'fails with unknown language'
    When run run_dev_init "$PROJ_DIR" tool ruby myapp
    The status should be failure
    The error should include 'unknown language'
  End

  It 'fails with unknown repo-type'
    When run run_dev_init "$PROJ_DIR" plugin bash myapp
    The status should be failure
    The error should include 'unknown repo-type'
  End

  It 'scaffolds a python/library project'
    When run run_dev_init "$PROJ_DIR" library python mylib
    The status should be success
    The output should include 'mylib'
  End

  It 'creates .dev with correct name and repo type for python/library'
    run_dev_init "$PROJ_DIR" library python mylib >/dev/null 2>&1
    When run cat "$PROJ_DIR/.dev"
    The output should include 'DEV_NAME=mylib'
    The output should include 'DEV_REPO_TYPE=library'
  End

  It 'fails when bash is used with library repo-type'
    When run run_dev_init "$PROJ_DIR" library bash mylib
    The status should be failure
    The error should include 'bash is only supported for tool repos'
  End

  It 'fails with missing arguments'
    When run run_dev_init "$PROJ_DIR"
    The status should be failure
    The error should include 'usage:'
  End
End
