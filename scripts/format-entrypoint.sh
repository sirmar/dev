#!/bin/sh
if [ $# -gt 0 ]; then
	case "$1" in
	*/spec/*.sh | spec/*.sh) exit 0 ;;
	*.sh) exec shfmt -w "$@" ;;
	*) exit 0 ;;
	esac
fi
files=$(find /workspace -name "*.sh" -not -path "*/.git/*" -not -path "*/spec/*")
[ -z "$files" ] && echo "no .sh files found" && exit 0
# shellcheck disable=SC2086
exec shfmt -w $files
