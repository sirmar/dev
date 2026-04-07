#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
LINK_NAME="dev"

if [ ! -f "$REPO_DIR/app/dev.sh" ]; then
	echo "error: app/dev.sh not found in $REPO_DIR" >&2
	exit 1
fi

mkdir -p "$INSTALL_DIR"
ln -sf "$REPO_DIR/app/dev.sh" "$INSTALL_DIR/$LINK_NAME"
echo "Installed: $INSTALL_DIR/$LINK_NAME -> $REPO_DIR/app/dev.sh"

if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
	echo "warning: $INSTALL_DIR is not in PATH — add it to your shell profile"
fi
