#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
LINK_NAME="dev"
LINK_PATH="$INSTALL_DIR/$LINK_NAME"

if [ ! -L "$LINK_PATH" ]; then
	echo "error: $LINK_PATH is not a symlink or does not exist" >&2
	exit 1
fi

rm "$LINK_PATH"
echo "Uninstalled: $LINK_PATH"
