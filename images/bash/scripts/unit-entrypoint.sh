#!/bin/sh
if [ $# -gt 0 ]; then
	exec shellspec "$@"
else
	exec shellspec src/spec
fi
