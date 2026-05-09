#!/bin/sh

_is_node_id() {
	case "$1" in *' > '*) return 0 ;; esac
	return 1
}

_run_narrowed() {
	_overall=0
	_idx=0
	_raw_files=''

	_files=$(printf '%s\n' "$@" | sed 's/ > .*//' | sort -u)
	for _file in $_files; do
		_pattern=$(printf '%s\n' "$@" | grep "^${_file} > " | sed "s|^${_file} > ||;s| > | |g" | awk 'NR>1{printf "|"}{printf "%s",$0}')
		_raw_tmp="/workspace/out/e2e-raw-${_idx}.json"
		pnpm vitest run --reporter=dot --reporter=json --outputFile="$_raw_tmp" "$_file" -t "$_pattern"
		_rc=$?
		[ "$_rc" -ne 0 ] && _overall=$_rc
		_raw_files="$_raw_files $_raw_tmp"
		_idx=$((_idx + 1))
	done

	# shellcheck disable=SC2086
	node -e "
    const fs = require('fs');
    const files = process.argv.slice(1);
    const merged = { testResults: files.flatMap(f => JSON.parse(fs.readFileSync(f)).testResults || []) };
    fs.writeFileSync('/workspace/out/e2e-raw.json', JSON.stringify(merged));
  " $_raw_files

	unit-normalizer /workspace/out/e2e-raw.json /workspace/out/e2e-result.json
	exit $_overall
}

_run_cmd() {
	pnpm vitest run --reporter=dot --reporter=json --outputFile=/workspace/out/e2e-raw.json "$@"
	_exit=$?
	unit-normalizer /workspace/out/e2e-raw.json /workspace/out/e2e-result.json
	exit $_exit
}
# shellcheck source=/dev/null
. entrypoint-helper.sh

if [ $# -gt 0 ] && _is_node_id "$1"; then
	_run_narrowed "$@"
else
	run_entrypoint '' "$@"
fi
