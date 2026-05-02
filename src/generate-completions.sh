#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2016
set -euo pipefail

DEV_SCRIPT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/src/app/dev.sh}"
OUT_DIR="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/completions}"
MDEV_SCRIPT="${3:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/src/app/mdev.sh}"

# shellcheck source=/dev/null
source "$DEV_SCRIPT"

mkdir -p "$OUT_DIR"

# ---------------------------------------------------------------------------
# bash completion
# ---------------------------------------------------------------------------

{
	cat <<'HEADER'
#!/usr/bin/env bash

_dev_fix_files() {
	local i
	for ((i = 0; i < ${#COMPREPLY[@]}; i++)); do
		if [[ -d "${COMPREPLY[$i]}" ]]; then
			COMPREPLY[$i]+="/"
		else
			COMPREPLY[$i]+=" "
		fi
	done
}

_dev_completion() {
	local cur subcmd
	cur="${COMP_WORDS[COMP_CWORD]}"

	if [[ $COMP_CWORD -eq 1 ]]; then
		local all_cmds
		all_cmds="$(dev completions 2>/dev/null)"
		COMPREPLY=($(compgen -W "$all_cmds" -- "$cur"))
		COMPREPLY=("${COMPREPLY[@]/%/ }")
		return
	fi

	subcmd="${COMP_WORDS[1]}"

	case "$subcmd" in
HEADER

	for cmd in "${_DEV_COMMANDS[@]}"; do
		args="$(cmd_args "$cmd")"
		[[ -z "$args" ]] && continue
		printf '\t\t%s)\n' "$cmd"
		printf '\t\t\tCOMPREPLY=($( compgen -W "%s" -- "$cur"))\n' "$args"
		printf '\t\t\tCOMPREPLY=("${COMPREPLY[@]/%%/ }")\n'
		printf '\t\t\t;;\n'
	done

	cat <<'DYNAMIC'
		lint | format)
			COMPREPLY=($(compgen -f -- "$cur"))
			_dev_fix_files
			;;
		up)
			local compose_file=""
			for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
				if [[ -f "$f" ]]; then
					compose_file="$f"
					break
				fi
			done
			if [[ -n "$compose_file" ]]; then
				local services
				services=$(grep -E '^  [a-zA-Z0-9_-]+:' "$compose_file" 2>/dev/null | sed 's/://;s/^ *//' || true)
				COMPREPLY=($(compgen -W "$services" -- "$cur"))
				COMPREPLY=("${COMPREPLY[@]/%/ }")
			fi
			;;
		logs)
			local compose_file=""
			for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
				if [[ -f "$f" ]]; then
					compose_file="$f"
					break
				fi
			done
			local opts="-f --follow"
			if [[ -n "$compose_file" ]]; then
				local services
				services=$(grep -E '^  [a-zA-Z0-9_-]+:' "$compose_file" 2>/dev/null | sed 's/://;s/^ *//' || true)
				opts="$opts $services"
			fi
			COMPREPLY=($(compgen -W "$opts" -- "$cur"))
			COMPREPLY=("${COMPREPLY[@]/%/ }")
			;;
		exec)
			COMPREPLY=($(compgen -W "$(dev list-scripts 2>/dev/null)" -- "$cur"))
			COMPREPLY=("${COMPREPLY[@]/%/ }")
			;;
		*)
			COMPREPLY=($(compgen -f -- "$cur"))
			_dev_fix_files
			;;
	esac
}

complete -o nospace -o default -F _dev_completion dev
DYNAMIC
} >"$OUT_DIR/dev.bash"

# ---------------------------------------------------------------------------
# zsh completion
# ---------------------------------------------------------------------------

{
	cat <<'ZSH_HEADER'
#compdef dev

_dev() {
	if (( CURRENT == 2 )); then
		local -a commands
		commands=(${(ps: :)"$(dev completions 2>/dev/null)"})
		_describe 'command' commands
		return
	fi

	local subcmd="${words[2]}"

	case "$subcmd" in
ZSH_HEADER

	for cmd in "${_DEV_COMMANDS[@]}"; do
		args="$(cmd_args "$cmd")"
		[[ -z "$args" ]] && continue
		case "$cmd" in
		init)
			cat <<'ZSH_INIT'
		init)
			if (( CURRENT == 3 )); then
				local -a types
				types=('tool:CLI tool' 'service:Long-running service' 'image:Base Docker image' 'library:Reusable library')
				_describe 'repo type' types
			elif (( CURRENT == 4 )) && [[ "${words[3]}" != "image" ]]; then
				local -a langs
				langs=('bash:Bash' 'python:Python' 'typescript:TypeScript')
				_describe 'language' langs
			fi
			;;
ZSH_INIT
			;;
		release)
			cat <<'ZSH_RELEASE'
		release)
			local -a types
			types=(
				'major:Bump major version'
				'minor:Bump minor version'
				'patch:Bump patch version'
			)
			_describe 'release type' types
			;;
ZSH_RELEASE
			;;
		*)
			printf '\t\t%s)\n' "$cmd"
			printf '\t\t\tlocal -a opts\n'
			printf '\t\t\topts=(%s)\n' "$(echo "$args" | tr ' ' '\n' | sed "s/.*/'&'/" | tr '\n' ' ')"
			printf '\t\t\t_describe '"'"'option'"'"' opts\n'
			printf '\t\t\t;;\n'
			;;
		esac
	done

	cat <<'ZSH_DYNAMIC'
		lint | format)
			_files
			;;
		up)
			local compose_file=""
			for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
				[[ -f "$f" ]] && { compose_file="$f"; break; }
			done
			if [[ -n "$compose_file" ]]; then
				local -a services
				services=(${(f)"$(grep -E '^  [a-zA-Z0-9_-]+:' "$compose_file" 2>/dev/null | sed 's/://;s/^ *//' || true)"})
				_describe 'service' services
			fi
			;;
		logs)
			local -a log_opts
			log_opts=('-f:Follow log output' '--follow:Follow log output')
			local compose_file=""
			for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
				[[ -f "$f" ]] && { compose_file="$f"; break; }
			done
			if [[ -n "$compose_file" ]]; then
				local -a services
				services=(${(f)"$(grep -E '^  [a-zA-Z0-9_-]+:' "$compose_file" 2>/dev/null | sed 's/://;s/^ *//' || true)"})
				_describe 'option or service' log_opts
				_describe 'service' services
			else
				_describe 'option' log_opts
			fi
			;;
		exec)
			local -a scripts
			scripts=(${(f)"$(dev list-scripts 2>/dev/null)"})
			_describe 'script' scripts
			;;
		*)
			_default
			;;
	esac
}

_dev "$@"
ZSH_DYNAMIC
} >"$OUT_DIR/_dev"

echo "Generated: $OUT_DIR/dev.bash"
echo "Generated: $OUT_DIR/_dev"

# ---------------------------------------------------------------------------
# mdev completions
# ---------------------------------------------------------------------------

# shellcheck source=/dev/null
source "$MDEV_SCRIPT"

{
	cat <<'MDEV_BASH_HEADER'
#!/usr/bin/env bash

_mdev_fix_files() {
	local i
	for ((i = 0; i < ${#COMPREPLY[@]}; i++)); do
		if [[ -d "${COMPREPLY[$i]}" ]]; then
			COMPREPLY[$i]+='/'
		else
			COMPREPLY[$i]+=' '
		fi
	done
}

_mdev_services() { mdev services 2>/dev/null; }

_mdev_completion() {
	local cur subcmd
	cur="${COMP_WORDS[COMP_CWORD]}"

	if [[ $COMP_CWORD -eq 1 ]]; then
		local all_cmds
		all_cmds="$(mdev completions 2>/dev/null)"
		COMPREPLY=($(compgen -W "$all_cmds" -- "$cur"))
		COMPREPLY=("${COMPREPLY[@]/%/ }")
		return
	fi

	subcmd="${COMP_WORDS[1]}"

	case "$subcmd" in
MDEV_BASH_HEADER

	for cmd in "${MDEV_COMMANDS[@]}"; do
		arg_type="$(cmd_arg_type "$cmd")"
		case "$arg_type" in
		services)
			printf '\t\t%s)\n' "$cmd"
			printf '\t\t\tlocal services\n'
			printf '\t\t\tservices="$(_mdev_services)"\n'
			printf '\t\t\tCOMPREPLY=($(compgen -W "$services" -- "$cur"))\n'
			printf '\t\t\tCOMPREPLY=("${COMPREPLY[@]/%%%%/ }")\n'
			printf '\t\t\t;;\n'
			;;
		esac
	done

	cat <<'MDEV_BASH_DYNAMIC'
		logs)
			local opts='-f --follow'
			opts="$opts $(_mdev_services)"
			COMPREPLY=($(compgen -W "$opts" -- "$cur"))
			COMPREPLY=("${COMPREPLY[@]/%/ }")
			;;
		run)
			if [[ $COMP_CWORD -eq 2 ]]; then
				local services
				services="$(_mdev_services)"
				COMPREPLY=($(compgen -W "$services" -- "$cur"))
				COMPREPLY=("${COMPREPLY[@]/%/ }")
			elif [[ $COMP_CWORD -eq 3 ]]; then
				COMPREPLY=($(compgen -W "$(dev completions 2>/dev/null)" -- "$cur"))
				COMPREPLY=("${COMPREPLY[@]/%/ }")
			fi
			;;
		changed)
			COMPREPLY=($(compgen -W "origin/main main HEAD~1" -- "$cur"))
			COMPREPLY=("${COMPREPLY[@]/%/ }")
			;;
		*)
			COMPREPLY=($(compgen -f -- "$cur"))
			_mdev_fix_files
			;;
	esac
}

complete -o nospace -o default -F _mdev_completion mdev
MDEV_BASH_DYNAMIC
} >"$OUT_DIR/mdev.bash"

{
	cat <<'MDEV_ZSH_HEADER'
#compdef mdev

_mdev_services() { mdev services 2>/dev/null; }

_mdev() {
	if (( CURRENT == 2 )); then
		local -a commands
		commands=(${(ps: :)"$(mdev completions 2>/dev/null)"})
		_describe 'command' commands
		return
	fi

	local subcmd="${words[2]}"

	case "$subcmd" in
MDEV_ZSH_HEADER

	for cmd in "${MDEV_COMMANDS[@]}"; do
		arg_type="$(cmd_arg_type "$cmd")"
		case "$arg_type" in
		services)
			printf '\t\t%s)\n' "$cmd"
			printf '\t\t\tlocal -a services\n'
			printf '\t\t\tservices=(${(f)"$(_mdev_services)"})\n'
			printf '\t\t\t_describe '"'"'service'"'"' services\n'
			printf '\t\t\t;;\n'
			;;
		service)
			printf '\t\t%s)\n' "$cmd"
			printf '\t\t\tif (( CURRENT == 3 )); then\n'
			printf '\t\t\t\tlocal -a services\n'
			printf '\t\t\t\tservices=($${(f)"$(_mdev_services)"})\n'
			printf '\t\t\t\t_describe '"'"'service'"'"' services\n'
			printf '\t\t\tfi\n'
			printf '\t\t\t;;\n'
			;;
		esac
	done

	cat <<'MDEV_ZSH_DYNAMIC'
		logs)
			local -a log_opts
			log_opts=('-f:Follow log output' '--follow:Follow log output')
			_describe 'option' log_opts
			local -a services
			services=(${(f)"$(_mdev_services)"})
			_describe 'service' services
			;;
		run)
			if (( CURRENT == 3 )); then
				local -a services
				services=(${(f)"$(_mdev_services)"})
				_describe 'service' services
			elif (( CURRENT == 4 )); then
				local -a dev_cmds
				dev_cmds=(${(ps: :)"$(dev completions 2>/dev/null)"})
				_describe 'command' dev_cmds
			fi
			;;
		changed)
			local -a refs
			refs=('origin/main' 'main' 'HEAD~1')
			_describe 'ref' refs
			;;
		*)
			_default
			;;
	esac
}

_mdev "$@"
MDEV_ZSH_DYNAMIC
} >"$OUT_DIR/_mdev"

echo "Generated: $OUT_DIR/mdev.bash"
echo "Generated: $OUT_DIR/_mdev"
