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
		*)
			COMPREPLY=($(compgen -f -- "$cur"))
			_dev_fix_files
			;;
	esac
}

complete -o nospace -o default -F _dev_completion dev
