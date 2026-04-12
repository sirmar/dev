#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

Describe 'build (service repo)'
  Before 'setup_mock_docker'
  After 'teardown_mock_docker'

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

Describe 'build (CI mode)'
  setup_ci() {
    setup_mock_docker
    export CI=true
  }
  teardown_ci() {
    unset CI
    teardown_mock_docker
  }
  Before 'setup_ci'
  After 'teardown_ci'

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

Describe 'build (CI mode with registry)'
  setup_ci_registry() {
    setup_mock_docker
    export CI=true
    export GITHUB_SHA=abc123
    export GITHUB_TOKEN=token
    export GITHUB_ACTOR=actor
    export GITHUB_REPOSITORY_OWNER=org
    write_dev_config "$MOCK_DIR" dev service
  }
  teardown_ci_registry() {
    unset CI GITHUB_SHA GITHUB_TOKEN GITHUB_ACTOR GITHUB_REPOSITORY_OWNER
    teardown_mock_docker
  }
  Before 'setup_ci_registry'
  After 'teardown_ci_registry'

  It 'tags the image with the default registry and SHA'
    When run run_dev build
    The output should include 'docker tag dev ghcr.io/org/dev:abc123'
    The status should be success
  End

  It 'pushes the tagged image'
    When run run_dev build
    The output should include 'docker push ghcr.io/org/dev:abc123'
    The status should be success
  End

  It 'does not push when GITHUB_SHA is unset'
    unset GITHUB_SHA
    When run run_dev build
    The output should not include 'docker push'
    The status should be success
  End

  It 'does not push when DEV_REGISTRY and GITHUB_REPOSITORY_OWNER are unset'
    write_dev_config "$MOCK_DIR" dev service
    unset GITHUB_REPOSITORY_OWNER
    When run run_dev build
    The output should not include 'docker push'
    The status should be success
  End
End

Describe 'build (image repo with stages)'
  setup_image_repo() {
    setup_mock_docker
    write_dev_config "$MOCK_DIR" myimage image
    printf 'FROM scratch AS base\nFROM scratch AS amd64\nFROM scratch AS arm64\n' >"$MOCK_DIR/Dockerfile"
  }
  Before 'setup_image_repo'
  After 'teardown_mock_docker'

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
    setup_mock_docker
    write_dev_config "$MOCK_DIR" myimage image
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
