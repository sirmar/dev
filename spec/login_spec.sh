#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/spec/support/helpers.sh"

Describe 'login via gh'
  setup_login_gh() {
    setup_mock_docker
    cat >"$MOCK_DIR/gh" <<EOF
#!/bin/sh
case "\$1 \$2" in
"auth status") exit 0 ;;
"auth token") echo "ghs_mocktoken" ;;
"api user") echo "octocat" ;;
esac
EOF
    chmod +x "$MOCK_DIR/gh"
  }
  Before 'setup_login_gh'
  After 'teardown_mock_docker'

  It 'logs in to ghcr.io using gh credentials'
    When run run_dev login
    The output should include 'logging in to ghcr.io'
    The output should include 'docker login ghcr.io'
    The status should be success
  End
End

Describe 'login via DEV_REGISTRY config'
  setup_login_config() {
    setup_mock_docker
    write_dev_config "$MOCK_DIR" dev service "DEV_REGISTRY=registry.example.com/org" "DEV_REGISTRY_USER=myuser" "DEV_REGISTRY_TOKEN=mytoken"
    # No gh in PATH so it falls back to config
    rm -f "$MOCK_DIR/gh"
  }
  Before 'setup_login_config'
  After 'teardown_mock_docker'

  It 'logs in to the configured registry host'
    When run run_dev login
    The output should include 'logging in to registry.example.com'
    The output should include 'docker login registry.example.com'
    The status should be success
  End
End

Describe 'login with no credentials'
  setup_login_none() {
    setup_mock_docker
    rm -f "$MOCK_DIR/gh"
  }
  Before 'setup_login_none'
  After 'teardown_mock_docker'

  It 'errors with helpful message'
    When run run_dev login
    The status should be failure
    The stderr should include 'no credentials found'
  End
End
