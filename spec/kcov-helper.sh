#!/bin/sh
# shellcheck shell=bash

[ -n "$KCOV_BASH_XTRACEFD" ] && {
	trap 'echo "kcov@${BASH_SOURCE}@${LINENO}@" >&$KCOV_BASH_XTRACEFD' DEBUG
	set -o functrace
}
