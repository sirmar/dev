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

for hook in claude-lint claude-format; do
	[[ -L "$INSTALL_DIR/$hook" ]] && rm "$INSTALL_DIR/$hook" && echo "Uninstalled: $INSTALL_DIR/$hook"
done

BASH_COMPLETION_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
ZSH_COMPLETION_DIR="${ZDOTDIR:-$HOME}/.zfunc"

[[ -L "$BASH_COMPLETION_DIR/dev" ]] && rm "$BASH_COMPLETION_DIR/dev" && echo "Removed bash completion: $BASH_COMPLETION_DIR/dev"
[[ -L "$ZSH_COMPLETION_DIR/_dev" ]] && rm "$ZSH_COMPLETION_DIR/_dev" && echo "Removed zsh completion: $ZSH_COMPLETION_DIR/_dev"

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dev/config"
if [[ -f "$CONFIG_FILE" ]]; then
	echo "Config file left in place: $CONFIG_FILE"
	echo "Remove manually if no longer needed: rm $CONFIG_FILE"
fi
