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
		init)
			if [[ $COMP_CWORD -eq 2 ]]; then
				COMPREPLY=($(compgen -W "tool service image" -- "$cur"))
				COMPREPLY=("${COMPREPLY[@]/%/ }")
			elif [[ $COMP_CWORD -eq 3 && "${COMP_WORDS[2]}" != "image" ]]; then
				COMPREPLY=($(compgen -W "bash python typescript" -- "$cur"))
				COMPREPLY=("${COMPREPLY[@]/%/ }")
			fi
			;;
		build)
			COMPREPLY=($(compgen -W "--no-cache" -- "$cur"))
			COMPREPLY=("${COMPREPLY[@]/%/ }")
			;;
		release)
			COMPREPLY=($(compgen -W "major minor patch" -- "$cur"))
			COMPREPLY=("${COMPREPLY[@]/%/ }")
			;;
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
