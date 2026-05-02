#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2016
set -euo pipefail

DEV_SCRIPT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/src/app/dev.sh}"
OUT_DIR="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/completions}"

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
			local dev_scripts="" script_names=""
			local dir="$PWD"
			while [[ "$dir" != "/" ]]; do
				if [[ -f "$dir/.dev" ]]; then
					dev_scripts="$(grep -m1 '^DEV_SCRIPTS=' "$dir/.dev" | cut -d= -f2- | tr -d '"' || true)"
					break
				fi
				dir="$(dirname "$dir")"
			done
			script_names="$(echo "$dev_scripts" | tr ' ' '\n' | cut -d: -f1 | tr '\n' ' ')"
			COMPREPLY=($(compgen -W "$script_names" -- "$cur"))
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
			local dev_scripts=""
			local dir="$PWD"
			while [[ "$dir" != "/" ]]; do
				[[ -f "$dir/.dev" ]] && { dev_scripts="$(grep -m1 '^DEV_SCRIPTS=' "$dir/.dev" | cut -d= -f2- | tr -d '"' || true)"; break; }
				dir="$(dirname "$dir")"
			done
			if [[ -n "$dev_scripts" ]]; then
				local -a scripts
				scripts=(${(f)"$(echo "$dev_scripts" | tr ' ' '\n' | cut -d: -f1)"})
				_describe 'script' scripts
			fi
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
