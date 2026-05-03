#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"
GENERATOR="$DEV_ROOT/src/generate-completions.sh"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

run_generator() {
  PROJ_DIR="$(mktemp -d)"
  bash "$GENERATOR" "$DEV_ROOT/src/app/dev.sh" "$PROJ_DIR" "$DEV_ROOT/src/app/mdev.sh" >/dev/null
  BASH_OUT="$PROJ_DIR/dev.bash"
  ZSH_OUT="$PROJ_DIR/_dev"
  MDEV_BASH_OUT="$PROJ_DIR/mdev.bash"
  MDEV_ZSH_OUT="$PROJ_DIR/_mdev"
  export PROJ_DIR BASH_OUT ZSH_OUT MDEV_BASH_OUT MDEV_ZSH_OUT
}

Describe 'generate-completions.sh'
  Before 'run_generator'
  After 'teardown'

  It 'produces a case branch for build with --no-cache in bash completion'
    When call cat "$BASH_OUT"
    The output should include 'build'
    The output should include '--no-cache'
  End

  It 'produces no duplicate case branch for up in bash completion'
    When call grep -c '^\s*up)' "$BASH_OUT"
    The output should equal '1'
  End

  It 'includes dynamic up logs exec blocks in bash completion'
    When call cat "$BASH_OUT"
    The output should include 'docker-compose'
    The output should include 'list-scripts'
  End

  It 'includes dynamic up logs exec blocks in zsh completion'
    When call cat "$ZSH_OUT"
    The output should include 'docker-compose'
    The output should include 'list-scripts'
  End

  It 'generates mdev bash completion file'
    When call test -f "$MDEV_BASH_OUT"
    The status should be success
  End

  It 'generates mdev zsh completion file'
    When call test -f "$MDEV_ZSH_OUT"
    The status should be success
  End

  It 'mdev bash completion includes lock (bug fix)'
    When call cat "$MDEV_BASH_OUT"
    The output should include 'lock'
  End

  It 'bash completion has explicit unit | coverage case for file completion'
    When call grep -q 'unit | coverage' "$BASH_OUT"
    The status should be success
  End

  It 'zsh completion has explicit unit | coverage case for file completion'
    When call grep -q 'unit | coverage' "$ZSH_OUT"
    The status should be success
  End
End
