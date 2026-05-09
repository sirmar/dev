#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

_setup_normalizer_env() {
  NORM_DIR="$(mktemp -d)"
  OUT_JSON="$NORM_DIR/unit-result.json"
  export NORM_DIR OUT_JSON
}

_teardown_normalizer_env() {
  rm -rf "$NORM_DIR"
}

_run_normalizer() {
  "$DEV_ROOT/images/bash/scripts/unit-normalizer" "$@"
}

Describe 'bash unit-normalizer'
  Before '_setup_normalizer_env'
  After '_teardown_normalizer_env'

  Describe 'all tests pass'
    It 'writes passed true with empty failures'
      tap_file="$NORM_DIR/unit.tap"
      printf '1..2\nok 1 - foo passes\nok 2 - bar passes\n' >"$tap_file"
      When run _run_normalizer "$tap_file" "$OUT_JSON"
      The status should be success
      The path "$OUT_JSON" should be exist
      The contents of file "$OUT_JSON" should include '"passed":true'
      The contents of file "$OUT_JSON" should include '"failures":[]'
    End
  End

  Describe 'some tests fail'
    It 'writes passed false with file:line node_ids'
      tap_file="$NORM_DIR/unit.tap"
      printf '1..3\nok 1 - foo passes\nnot ok 2 - foo fails # FAILED\n# (in specfile src/spec/foo_spec.sh, line 5)\nok 3 - bar passes\n' >"$tap_file"
      When run _run_normalizer "$tap_file" "$OUT_JSON"
      The status should be success
      The path "$OUT_JSON" should be exist
      The contents of file "$OUT_JSON" should include '"passed":false'
      The contents of file "$OUT_JSON" should include 'src/spec/foo_spec.sh:5'
      The contents of file "$OUT_JSON" should not include 'src/spec/bar_spec.sh'
    End
  End

  Describe 'all tests fail'
    It 'writes all failing node_ids'
      tap_file="$NORM_DIR/unit.tap"
      printf '1..2\nnot ok 1 - foo fails # FAILED\n# (in specfile src/spec/foo_spec.sh, line 1)\nnot ok 2 - bar fails # FAILED\n# (in specfile src/spec/bar_spec.sh, line 3)\n' >"$tap_file"
      When run _run_normalizer "$tap_file" "$OUT_JSON"
      The status should be success
      The path "$OUT_JSON" should be exist
      The contents of file "$OUT_JSON" should include '"passed":false'
      The contents of file "$OUT_JSON" should include 'src/spec/foo_spec.sh:1'
      The contents of file "$OUT_JSON" should include 'src/spec/bar_spec.sh:3'
    End
  End
End
