#!/bin/sh
if [ $# -gt 0 ]; then
	uv run pytest -q --cov --cov-report=term "$@" &&
		uv run coverage report --format=markdown >/workspace/out/coverage.md
else
	uv run pytest -q --cov --cov-report=term src/tests/ &&
		uv run coverage report --format=markdown >/workspace/out/coverage.md
fi
