#!/bin/sh
if [ $# -gt 0 ]; then
	case "$1" in
	*.sh) exec shellcheck -f gcc "$@" ;;
	*) exit 0 ;;
	esac
fi
files=$(find /workspace -name "*.sh" -not -path "*/.git/*")
[ -z "$files" ] && echo "no .sh files found" && exit 0
# shellcheck disable=SC2086
exec shellcheck -f gcc $files
