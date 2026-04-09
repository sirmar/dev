#!/bin/sh
if [ $# -gt 0 ]; then
	exec uv run ruff format "$@"
fi
exec uv run ruff format /workspace
