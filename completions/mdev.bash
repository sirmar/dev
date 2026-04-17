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
		up | down | build | lint | format | unit | check)
			local services
			services="$(_mdev_services)"
			COMPREPLY=($(compgen -W "$services" -- "$cur"))
			COMPREPLY=("${COMPREPLY[@]/%/ }")
			;;
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
