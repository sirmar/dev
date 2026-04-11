#!/bin/sh
exec uv run pytest -q --cov=src/app --cov-report=term src/tests/
