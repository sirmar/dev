#!/bin/sh
if [ $# -gt 0 ]; then
	exec uv run ruff check "$@"
fi
exec uv run ruff check /workspace
