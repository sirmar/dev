#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"
GENERATOR="$DEV_ROOT/src/generate-completions.sh"

run_generator() {
  OUT_DIR="$(mktemp -d)"
  bash "$GENERATOR" "$DEV_ROOT/src/app/dev.sh" "$OUT_DIR"
  BASH_OUT="$OUT_DIR/dev.bash"
  ZSH_OUT="$OUT_DIR/_dev"
  export OUT_DIR BASH_OUT ZSH_OUT
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
    The output should include 'DEV_SCRIPTS'
  End

  It 'includes dynamic up logs exec blocks in zsh completion'
    When call cat "$ZSH_OUT"
    The output should include 'docker-compose'
    The output should include 'DEV_SCRIPTS'
  End
End
