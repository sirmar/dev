# shellcheck shell=bash
# shellcheck disable=SC1091
. "$SHELLSPEC_PROJECT_ROOT/src/spec/support/helpers.sh"

shellspec_spec_helper_configure() {
	if [ "$SHELLSPEC_KCOV" ]; then
		export BASH_ENV="$SHELLSPEC_PROJECT_ROOT/src/spec/support/kcov-helper.sh"
	fi
}
