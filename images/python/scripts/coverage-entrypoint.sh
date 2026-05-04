#!/bin/sh
_run_cmd() { uv run pytest -q --cov --cov-report=term "$@"; }
# shellcheck source=/dev/null
. entrypoint-helper.sh
run_entrypoint 'src/tests/' "$@" &&
	uv run coverage report --format=markdown >/workspace/out/coverage.md
