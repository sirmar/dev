#!/bin/sh
exec uv run bandit -q -r src/app/ -c pyproject.toml
