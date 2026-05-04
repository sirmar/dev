#!/bin/sh
_run_cmd() { exec uv run ruff check "$@"; }
# shellcheck source=/dev/null
. entrypoint-helper.sh
run_entrypoint_filtered '/workspace' '*.py' "$@"
