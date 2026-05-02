#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"
GENERATOR="$DEV_ROOT/src/generate-completions.sh"

run_generator() {
  OUT_DIR="$(mktemp -d)"
  bash "$GENERATOR" "$DEV_ROOT/src/app/dev.sh" "$OUT_DIR" "$DEV_ROOT/src/app/mdev.sh" >/dev/null
  BASH_OUT="$OUT_DIR/dev.bash"
  ZSH_OUT="$OUT_DIR/_dev"
  MDEV_BASH_OUT="$OUT_DIR/mdev.bash"
  MDEV_ZSH_OUT="$OUT_DIR/_mdev"
  export OUT_DIR BASH_OUT ZSH_OUT MDEV_BASH_OUT MDEV_ZSH_OUT
}

cleanup_generator() { rm -rf "$OUT_DIR"; }

Describe 'generate-completions.sh'
  Before 'run_generator'
  After 'cleanup_generator'

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
End
