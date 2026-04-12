#!/bin/sh
if [ $# -gt 0 ]; then
	files=$(for f in "$@"; do case "$f" in *.py) echo "$f" ;; esac; done)
	[ -z "$files" ] && exit 0
	# shellcheck disable=SC2086
	exec uv run ruff check $files
fi
exec uv run ruff check /workspace
