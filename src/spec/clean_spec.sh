#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317



Describe 'clean'
  Before 'fixture_service_proj'
  After 'teardown'

  It 'removes containers and volumes via compose down -v'
    When run bash -c "cd '$PROJ_DIR' && bash dev.sh clean"
    The output should include 'removing services and volumes'
    The output should include 'down -v'
    The status should be success
  End

  It 'does not run e2e compose when docker-compose.e2e.yml is absent'
    When run bash -c "cd '$PROJ_DIR' && bash dev.sh clean"
    The output should not include 'e2e-network'
    The status should be success
  End

  It 'also cleans e2e compose when docker-compose.e2e.yml is present'
    touch "$PROJ_DIR/docker-compose.e2e.yml"
    When run bash -c "cd '$PROJ_DIR' && bash dev.sh clean"
    The output should include 'docker-compose.e2e.yml'
    The output should include 'docker-compose.e2e-network.yml'
    The status should be success
  End
End
