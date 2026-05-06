#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317



Describe 'tag'
  Before 'fixture_git_repo'
  After 'teardown'

  It 'prints the latest tag'
    When run bash -c "cd '$MOCK_DIR' && git tag v1.2.3 && bash dev.sh tag"
    The output should eq 'v1.2.3'
    The status should be success
  End

  It 'fails when no tag exists'
    When run bash -c "cd '$MOCK_DIR' && bash dev.sh tag"
    The status should be failure
    The stderr should include 'no git tag found'
  End
End
