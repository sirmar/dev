#!/bin/sh
if [ $# -gt 0 ]; then
	case "$1" in
	*.sh) exec shfmt -w "$@" ;;
	*) exit 0 ;;
	esac
fi
files=$(find /workspace -name "*.sh" -not -path "*/.git/*")
[ -z "$files" ] && echo "no .sh files found" && exit 0
# shellcheck disable=SC2086
exec shfmt -w $files
