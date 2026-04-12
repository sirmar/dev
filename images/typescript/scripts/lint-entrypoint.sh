#!/bin/sh
if [ $# -gt 0 ]; then
	files=$(for f in "$@"; do case "$f" in *.ts|*.tsx|*.js|*.jsx) echo "$f" ;; esac; done)
	[ -z "$files" ] && exit 0
	# shellcheck disable=SC2086
	exec pnpm exec biome check $files
fi
exec pnpm exec biome check .
