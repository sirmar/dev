#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317



Describe 'release'
  Before 'fixture_git_repo'
  After 'teardown'

  It 'fails without a bump type'
    When run bash -c "cd '$MOCK_DIR' && bash dev.sh release"
    The status should be failure
    The stderr should include 'major|minor|patch'
  End

  It 'fails with invalid bump type'
    When run bash -c "cd '$MOCK_DIR' && bash dev.sh release banana"
    The status should be failure
    The stderr should include 'major|minor|patch'
  End

  It 'bumps patch version from v0.0.0'
    When run bash -c "cd '$MOCK_DIR' && bash dev.sh release patch"
    The output should include 'v0.0.0 -> v0.0.1'
    The status should be success
  End

  It 'bumps minor version and resets patch'
    When run bash -c "cd '$MOCK_DIR' && git tag v1.2.3 && bash dev.sh release minor"
    The output should include 'v1.2.3 -> v1.3.0'
    The status should be success
  End

  It 'bumps major version and resets minor and patch'
    When run bash -c "cd '$MOCK_DIR' && git tag v1.2.3 && bash dev.sh release major"
    The output should include 'v1.2.3 -> v2.0.0'
    The status should be success
  End
End
