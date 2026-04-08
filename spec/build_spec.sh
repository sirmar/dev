#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"
DEV_SCRIPT="$DEV_ROOT/app/dev.sh"

# shellcheck disable=SC1091
. "$DEV_ROOT/spec/support/helpers.sh"

Describe 'build (service repo)'
  Before 'setup_mock_docker'
  After 'teardown_mock_docker'

  It 'builds the app image'
    When run bash "$DEV_SCRIPT" build
    The output should include 'docker build --target app'
    The status should be success
  End

  It 'tags the app image as DEV_NAME without a suffix'
    When run bash "$DEV_SCRIPT" build
    The output should include '-t dev '
    The output should not include '-t dev-app'
    The status should be success
  End

  It 'always passes Dockerfile from project root'
    When run bash "$DEV_SCRIPT" build
    The output should match pattern '*docker build*-f */Dockerfile *'
    The status should be success
  End
End

Describe 'build (image repo with stages)'
  setup_image_repo() {
    setup_mock_docker
    printf 'DEV_NAME=myimage\nDEV_SERVICE=app\nDEV_REPO_TYPE=image\n' >"$MOCK_DIR/.dev"
    printf 'FROM scratch AS base\nFROM scratch AS amd64\nFROM scratch AS arm64\n' >"$MOCK_DIR/Dockerfile"
  }
  Before 'setup_image_repo'
  After 'teardown_mock_docker'

  It 'builds each non-base stage'
    When run run_dev build
    The output should include 'building stage amd64'
    The output should include 'building stage arm64'
    The status should be success
  End

  It 'does not build the base stage'
    When run run_dev build
    The output should not include 'building stage base'
    The status should be success
  End
End

Describe 'build (image repo with no stages)'
  setup_image_repo_no_stages() {
    setup_mock_docker
    printf 'DEV_NAME=myimage\nDEV_SERVICE=app\nDEV_REPO_TYPE=image\n' >"$MOCK_DIR/.dev"
    printf 'FROM scratch\n' >"$MOCK_DIR/Dockerfile"
  }
  Before 'setup_image_repo_no_stages'
  After 'teardown_mock_docker'

  It 'builds image without a target stage'
    When run run_dev build
    The output should include 'building image'
    The output should not include 'building stage'
    The status should be success
  End

  It 'tags image as DEV_NAME'
    When run run_dev build
    The output should include '-t myimage'
    The status should be success
  End
End
