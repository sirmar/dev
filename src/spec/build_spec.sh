#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317



Describe 'build (service repo)'
  Before 'fixture_service_repo'
  After 'teardown'

  It 'builds the prod image'
    When run run_dev build
    The output should include 'docker build --target prod'
    The status should be success
  End

  It 'tags the prod image as DEV_NAME without a suffix'
    When run run_dev build
    The output should include '-t dev '
    The output should not include '-t dev-prod'
    The status should be success
  End

  It 'always passes Dockerfile from project root'
    When run run_dev build
    The output should match pattern '*docker build*-f */Dockerfile *'
    The status should be success
  End

  It 'passes --no-cache to docker build when flag is given'
    When run run_dev build --no-cache
    The output should include 'docker build --no-cache'
    The status should be success
  End

  It 'does not pass --no-cache by default'
    When run run_dev build
    The output should not include '--no-cache'
    The status should be success
  End
End

Describe 'build (CI mode with login)'
  Before 'fixture_service_repo_with_ci_login'
  After 'teardown_ci'

  It 'logs in to ghcr.io before building'
    When run run_dev build
    The output should include 'logging in to ghcr.io'
    The output should include 'docker buildx build'
    The status should be success
  End
End

Describe 'build (CI mode)'
  Before 'fixture_service_repo_with_ci'
  After 'teardown_ci'

  It 'does not log in when GITHUB_TOKEN is not set'
    When run run_dev build
    The output should not include 'logging in to ghcr.io'
    The status should be success
  End

  It 'uses docker buildx build with --load'
    When run run_dev build
    The output should include 'docker buildx build'
    The output should include '--load'
    The status should be success
  End

  It 'does not use plain docker build'
    When run run_dev build
    The output should not include 'docker build --target'
    The status should be success
  End

  It 'passes GHA cache-from and cache-to flags with DEV_NAME-stage scope'
    When run run_dev lint
    The output should include '--cache-from type=gha,scope=dev-lint'
    The output should include '--cache-to type=gha,mode=max,scope=dev-lint'
    The status should be success
  End
End

Describe 'build (image repo with stages)'
  setup_image_repo() {
    fixture_service_repo
    write_dev_config "$MOCK_DIR" myimage image
    printf 'FROM scratch AS base\nFROM scratch AS amd64\nFROM scratch AS arm64\n' >"$MOCK_DIR/Dockerfile"
  }
  Before 'setup_image_repo'
  After 'teardown'

  It 'builds base stage first, then each other stage'
    When run run_dev build
    The output should include 'building stage base'
    The output should include 'building stage amd64'
    The output should include 'building stage arm64'
    The status should be success
  End
End

Describe 'build (image repo with no stages)'
  setup_image_repo_no_stages() {
    fixture_service_repo
    write_dev_config "$MOCK_DIR" myimage image
    printf 'FROM scratch\n' >"$MOCK_DIR/Dockerfile"
  }
  Before 'setup_image_repo_no_stages'
  After 'teardown'

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
