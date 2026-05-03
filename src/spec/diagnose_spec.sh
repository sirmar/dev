#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

Describe 'diagnose'
  Describe 'system checks'
    Describe 'when all system checks pass'
      setup_diagnose_system() {
        MOCK_DIR="$(mktemp -d)"
        printf '#!/bin/sh\necho "docker $*"\n' >"$MOCK_DIR/docker"
        chmod +x "$MOCK_DIR/docker"
        export MOCK_DIR PATH="$MOCK_DIR:$PATH"
      }
      teardown_diagnose_system() { rm -rf "$MOCK_DIR"; }
      Before 'setup_diagnose_system'
      After 'teardown_diagnose_system'

      It 'prints [system] header and exits 0'
        When run run_dev diagnose
        The output should include '[system]'
        The status should be success
      End
    End

    Describe 'when docker daemon is not running'
      setup_diagnose_daemon_down() {
        MOCK_DIR="$(mktemp -d)"
        printf '#!/bin/sh\ncase "$*" in info*) exit 1;; *) echo "docker $*";; esac\n' >"$MOCK_DIR/docker"
        chmod +x "$MOCK_DIR/docker"
        export MOCK_DIR PATH="$MOCK_DIR:$PATH"
      }
      teardown_diagnose_daemon_down() { rm -rf "$MOCK_DIR"; }
      Before 'setup_diagnose_daemon_down'
      After 'teardown_diagnose_daemon_down'

      It 'prints error and exits 1'
        When run run_dev diagnose
        The output should include '[system]'
        The error should include 'docker daemon not running'
        The status should be failure
      End
    End

    Describe 'when docker compose v2 is not available'
      setup_diagnose_no_compose() {
        MOCK_DIR="$(mktemp -d)"
        printf '#!/bin/sh\ncase "$*" in "compose version"*) exit 1;; *) echo "docker $*";; esac\n' >"$MOCK_DIR/docker"
        chmod +x "$MOCK_DIR/docker"
        export MOCK_DIR PATH="$MOCK_DIR:$PATH"
      }
      teardown_diagnose_no_compose() { rm -rf "$MOCK_DIR"; }
      Before 'setup_diagnose_no_compose'
      After 'teardown_diagnose_no_compose'

      It 'prints error and exits 1'
        When run run_dev diagnose
        The output should include '[system]'
        The error should include 'docker compose v2 not available'
        The status should be failure
      End
    End

    Describe 'when docker binary is missing'
      setup_diagnose_no_docker() {
        MOCK_DIR="$(mktemp -d)"
        export MOCK_DIR PATH="$MOCK_DIR:$PATH"
      }
      teardown_diagnose_no_docker() { rm -rf "$MOCK_DIR"; }
      Before 'setup_diagnose_no_docker'
      After 'teardown_diagnose_no_docker'

      It 'prints error and exits 1'
        When run run_dev diagnose
        The output should include '[system]'
        The error should include 'docker not found in PATH'
        The status should be failure
      End
    End
  End

  Describe '--repo-only flag'
    setup_diagnose_repo_only() {
      MOCK_DIR="$(mktemp -d)"
      printf '#!/bin/sh\necho "docker $*"\n' >"$MOCK_DIR/docker"
      chmod +x "$MOCK_DIR/docker"
      write_dev_config "$MOCK_DIR" myapp service
      printf '%s\n' "$_MOCK_DOCKERFILE" >"$MOCK_DIR/Dockerfile"
      touch "$MOCK_DIR/docker-compose.yml"
      export MOCK_DIR PATH="$MOCK_DIR:$PATH"
    }
    teardown_diagnose_repo_only() { rm -rf "$MOCK_DIR"; }
    Before 'setup_diagnose_repo_only'
    After 'teardown_diagnose_repo_only'

    It 'skips system checks'
      When run run_dev diagnose --repo-only
      The output should not include '[system]'
      The status should be success
    End

    It 'still runs repo checks'
      When run run_dev diagnose --repo-only
      The output should include '[repo]'
      The status should be success
    End
  End

  Describe 'repo checks'
    Describe 'when .dev file is present and all repo checks pass'
      setup_diagnose_repo_ok() {
        MOCK_DIR="$(mktemp -d)"
        printf '#!/bin/sh\necho "docker $*"\n' >"$MOCK_DIR/docker"
        chmod +x "$MOCK_DIR/docker"
        write_dev_config "$MOCK_DIR" myapp service
        printf '%s\n' "$_MOCK_DOCKERFILE" >"$MOCK_DIR/Dockerfile"
        touch "$MOCK_DIR/docker-compose.yml"
        export MOCK_DIR PATH="$MOCK_DIR:$PATH"
      }
      teardown_diagnose_repo_ok() { rm -rf "$MOCK_DIR"; }
      Before 'setup_diagnose_repo_ok'
      After 'teardown_diagnose_repo_ok'

      It 'prints [repo] header and exits 0'
        When run run_dev diagnose
        The output should include '[repo]'
        The status should be success
      End
    End

    Describe 'when DEV_NAME is missing'
      setup_diagnose_no_name() {
        MOCK_DIR="$(mktemp -d)"
        printf '#!/bin/sh\necho "docker $*"\n' >"$MOCK_DIR/docker"
        chmod +x "$MOCK_DIR/docker"
        printf 'DEV_REPO_TYPE=service\n' >"$MOCK_DIR/.dev"
        printf '%s\n' "$_MOCK_DOCKERFILE" >"$MOCK_DIR/Dockerfile"
        touch "$MOCK_DIR/docker-compose.yml"
        export MOCK_DIR PATH="$MOCK_DIR:$PATH"
      }
      teardown_diagnose_no_name() { rm -rf "$MOCK_DIR"; }
      Before 'setup_diagnose_no_name'
      After 'teardown_diagnose_no_name'

      It 'prints error and exits 1'
        When run run_dev diagnose
        The output should include '[repo]'
        The error should include 'DEV_NAME is not set'
        The status should be failure
      End
    End

    Describe 'when DEV_REPO_TYPE is missing'
      setup_diagnose_no_type() {
        MOCK_DIR="$(mktemp -d)"
        printf '#!/bin/sh\necho "docker $*"\n' >"$MOCK_DIR/docker"
        chmod +x "$MOCK_DIR/docker"
        printf 'DEV_NAME=myapp\n' >"$MOCK_DIR/.dev"
        printf '%s\n' "$_MOCK_DOCKERFILE" >"$MOCK_DIR/Dockerfile"
        touch "$MOCK_DIR/docker-compose.yml"
        export MOCK_DIR PATH="$MOCK_DIR:$PATH"
      }
      teardown_diagnose_no_type() { rm -rf "$MOCK_DIR"; }
      Before 'setup_diagnose_no_type'
      After 'teardown_diagnose_no_type'

      It 'prints error and exits 1'
        When run run_dev diagnose
        The output should include '[repo]'
        The error should include 'DEV_REPO_TYPE is not set'
        The status should be failure
      End
    End

    Describe 'when DEV_REPO_TYPE is unknown'
      setup_diagnose_bad_type() {
        MOCK_DIR="$(mktemp -d)"
        printf '#!/bin/sh\necho "docker $*"\n' >"$MOCK_DIR/docker"
        chmod +x "$MOCK_DIR/docker"
        write_dev_config "$MOCK_DIR" myapp badtype
        printf '%s\n' "$_MOCK_DOCKERFILE" >"$MOCK_DIR/Dockerfile"
        touch "$MOCK_DIR/docker-compose.yml"
        export MOCK_DIR PATH="$MOCK_DIR:$PATH"
      }
      teardown_diagnose_bad_type() { rm -rf "$MOCK_DIR"; }
      Before 'setup_diagnose_bad_type'
      After 'teardown_diagnose_bad_type'

      It 'prints error and exits 1'
        When run run_dev diagnose
        The output should include '[repo]'
        The error should include "DEV_REPO_TYPE 'badtype' is not a known type"
        The status should be failure
      End
    End

    Describe 'when Dockerfile is missing'
      setup_diagnose_no_dockerfile() {
        MOCK_DIR="$(mktemp -d)"
        printf '#!/bin/sh\necho "docker $*"\n' >"$MOCK_DIR/docker"
        chmod +x "$MOCK_DIR/docker"
        write_dev_config "$MOCK_DIR" myapp service
        touch "$MOCK_DIR/docker-compose.yml"
        export MOCK_DIR PATH="$MOCK_DIR:$PATH"
      }
      teardown_diagnose_no_dockerfile() { rm -rf "$MOCK_DIR"; }
      Before 'setup_diagnose_no_dockerfile'
      After 'teardown_diagnose_no_dockerfile'

      It 'prints error and exits 1'
        When run run_dev diagnose
        The output should include '[repo]'
        The error should include 'Dockerfile not found'
        The status should be failure
      End
    End

    Describe 'when docker-compose.yml is missing'
      setup_diagnose_no_compose_file() {
        MOCK_DIR="$(mktemp -d)"
        printf '#!/bin/sh\necho "docker $*"\n' >"$MOCK_DIR/docker"
        chmod +x "$MOCK_DIR/docker"
        write_dev_config "$MOCK_DIR" myapp service
        printf '%s\n' "$_MOCK_DOCKERFILE" >"$MOCK_DIR/Dockerfile"
        export MOCK_DIR PATH="$MOCK_DIR:$PATH"
      }
      teardown_diagnose_no_compose_file() { rm -rf "$MOCK_DIR"; }
      Before 'setup_diagnose_no_compose_file'
      After 'teardown_diagnose_no_compose_file'

      It 'prints error and exits 1'
        When run run_dev diagnose
        The output should include '[repo]'
        The error should include 'docker-compose.yml not found'
        The status should be failure
      End
    End

    Describe 'when base image tag is stale'
      setup_diagnose_stale_tag() {
        MOCK_DIR="$(mktemp -d)"
        printf '#!/bin/sh\necho "docker $*"\n' >"$MOCK_DIR/docker"
        chmod +x "$MOCK_DIR/docker"
        write_dev_config "$MOCK_DIR" myapp service
        printf 'FROM ghcr.io/org/dev:v0.0.1 AS lint\n' >"$MOCK_DIR/Dockerfile"
        touch "$MOCK_DIR/docker-compose.yml"
        # mock git to return a newer tag
        printf '#!/bin/sh\necho "v0.0.2"\n' >"$MOCK_DIR/git"
        chmod +x "$MOCK_DIR/git"
        export MOCK_DIR PATH="$MOCK_DIR:$PATH"
      }
      teardown_diagnose_stale_tag() { rm -rf "$MOCK_DIR"; }
      Before 'setup_diagnose_stale_tag'
      After 'teardown_diagnose_stale_tag'

      It 'prints error and exits 1'
        When run run_dev diagnose
        The output should include '[repo]'
        The error should include 'does not match dev tag'
        The status should be failure
      End
    End

    Describe 'when dev has no git tag'
      setup_diagnose_no_tag() {
        MOCK_DIR="$(mktemp -d)"
        printf '#!/bin/sh\necho "docker $*"\n' >"$MOCK_DIR/docker"
        chmod +x "$MOCK_DIR/docker"
        write_dev_config "$MOCK_DIR" myapp service
        printf 'FROM ghcr.io/org/dev:v0.0.1 AS lint\n' >"$MOCK_DIR/Dockerfile"
        touch "$MOCK_DIR/docker-compose.yml"
        # mock git to return nothing (no tag)
        printf '#!/bin/sh\nexit 1\n' >"$MOCK_DIR/git"
        chmod +x "$MOCK_DIR/git"
        export MOCK_DIR PATH="$MOCK_DIR:$PATH"
      }
      teardown_diagnose_no_tag() { rm -rf "$MOCK_DIR"; }
      Before 'setup_diagnose_no_tag'
      After 'teardown_diagnose_no_tag'

      It 'skips tag check and exits 0'
        When run run_dev diagnose
        The output should include 'skipping base image tag check'
        The status should be success
      End
    End

    Describe 'when repo type is tool (no docker-compose.yml needed)'
      setup_diagnose_tool_no_compose() {
        MOCK_DIR="$(mktemp -d)"
        printf '#!/bin/sh\necho "docker $*"\n' >"$MOCK_DIR/docker"
        chmod +x "$MOCK_DIR/docker"
        write_dev_config "$MOCK_DIR" mytool tool
        printf '%s\n' "$_MOCK_DOCKERFILE" >"$MOCK_DIR/Dockerfile"
        export MOCK_DIR PATH="$MOCK_DIR:$PATH"
      }
      teardown_diagnose_tool_no_compose() { rm -rf "$MOCK_DIR"; }
      Before 'setup_diagnose_tool_no_compose'
      After 'teardown_diagnose_tool_no_compose'

      It 'does not require docker-compose.yml and exits 0'
        When run run_dev diagnose
        The output should include '[repo]'
        The error should not include 'docker-compose.yml not found'
        The status should be success
      End
    End

    Describe 'when no .dev file is present'
      setup_diagnose_no_dev() {
        MOCK_DIR="$(mktemp -d)"
        printf '#!/bin/sh\necho "docker $*"\n' >"$MOCK_DIR/docker"
        chmod +x "$MOCK_DIR/docker"
        export MOCK_DIR PATH="$MOCK_DIR:$PATH"
      }
      teardown_diagnose_no_dev() { rm -rf "$MOCK_DIR"; }
      Before 'setup_diagnose_no_dev'
      After 'teardown_diagnose_no_dev'

      It 'skips repo checks and exits 0'
        When run run_dev diagnose
        The output should not include '[repo]'
        The status should be success
      End
    End
  End
End
