#!/bin/sh
exec uv run fastapi dev src/app/main.py --host 0.0.0.0 --port 8000 --reload-dir src/app
