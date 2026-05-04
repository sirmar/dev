#!/bin/sh
_run_cmd() { exec uv run ruff format "$@"; }
# shellcheck source=/dev/null
. entrypoint-helper.sh
run_entrypoint '/workspace' "$@"
