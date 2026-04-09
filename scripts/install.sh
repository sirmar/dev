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

BASH_COMPLETION_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
ZSH_COMPLETION_DIR="${ZDOTDIR:-$HOME}/.zfunc"

if [[ -f "$REPO_DIR/completions/dev.bash" ]]; then
	mkdir -p "$BASH_COMPLETION_DIR"
	ln -sf "$REPO_DIR/completions/dev.bash" "$BASH_COMPLETION_DIR/dev"
	echo "Installed bash completion: $BASH_COMPLETION_DIR/dev"
fi

if [[ -f "$REPO_DIR/completions/_dev" ]]; then
	mkdir -p "$ZSH_COMPLETION_DIR"
	ln -sf "$REPO_DIR/completions/_dev" "$ZSH_COMPLETION_DIR/_dev"
	echo "Installed zsh completion: $ZSH_COMPLETION_DIR/_dev"
	echo "Ensure fpath includes $ZSH_COMPLETION_DIR and compinit is called in your .zshrc"
fi

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dev/config"
if [[ ! -f "$CONFIG_FILE" ]]; then
	mkdir -p "$(dirname "$CONFIG_FILE")"
	cat >"$CONFIG_FILE" <<'EOF'
# dev user configuration
# Set these to enable dev login and dev push:
# DEV_REGISTRY=ghcr.io/your-org
# DEV_REGISTRY_USER=your-username
# DEV_REGISTRY_TOKEN=your-token   # or set GITHUB_TOKEN in your environment
EOF
	echo "Created config: $CONFIG_FILE — set DEV_REGISTRY, DEV_REGISTRY_USER, and DEV_REGISTRY_TOKEN to enable dev push"
else
	grep -q 'DEV_REGISTRY' "$CONFIG_FILE" || echo "reminder: set DEV_REGISTRY, DEV_REGISTRY_USER, and DEV_REGISTRY_TOKEN in $CONFIG_FILE to enable dev push"
fi
