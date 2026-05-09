#!/bin/sh
_run_cmd() {
	mkdir -p /workspace/out
	shellspec --output tap "$@"
	_exit=$?
	unit-normalizer /workspace/report/results.tap /workspace/out/unit-result.json
	exit $_exit
}
# shellcheck source=/dev/null
. entrypoint-helper.sh
run_entrypoint 'src/spec' "$@"
