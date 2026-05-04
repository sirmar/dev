#!/bin/sh
# Define _run_cmd before sourcing, then call run_entrypoint or run_entrypoint_filtered.

run_entrypoint() {
	_default=$1
	shift
	if [ $# -gt 0 ]; then
		_run_cmd "$@"
	else
		_run_cmd "$_default"
	fi
}

run_entrypoint_filtered() {
	_default=$1
	shift
	_ext=$1
	shift
	if [ $# -gt 0 ]; then
		# shellcheck disable=SC2254
		_files=$(for f in "$@"; do case "$f" in $_ext) printf '%s\n' "$f" ;; esac done)
		[ -z "$_files" ] && exit 0
		# shellcheck disable=SC2086
		_run_cmd $_files
	else
		_run_cmd "$_default"
	fi
}
