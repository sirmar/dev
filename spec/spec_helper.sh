# shellcheck shell=sh

shellspec_spec_helper_configure() {
	if [ "$SHELLSPEC_KCOV" ]; then
		export BASH_ENV="$SHELLSPEC_PROJECT_ROOT/spec/support/kcov-helper.sh"
	fi
}
