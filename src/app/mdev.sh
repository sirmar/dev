#!/usr/bin/env bash
set -euo pipefail

VERSION='0.1.0'
export DOCKER_CLI_HINTS=false

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

info() {
	echo -e "[${MDEV_NAME:-mdev}] \033[0;32m$*\033[0m"
}

warn() {
	echo -e "[${MDEV_NAME:-mdev}] \033[0;33m$*\033[0m" >&2
}

error() {
	echo -e "[${MDEV_NAME:-mdev}] \033[0;31m$*\033[0m" >&2
	exit 1
}

die() {
	echo -e "\033[0;31m$*\033[0m" >&2
	exit 1
}

# ---------------------------------------------------------------------------
# Core utilities
# ---------------------------------------------------------------------------

find_mdev_root() {
	local dir
	dir="$(pwd)"
	while [[ "$dir" != '/' ]]; do
		if [[ -f "$dir/.mdev" ]]; then
			echo "$dir"
			return 0
		fi
		dir="$(dirname "$dir")"
	done
	die 'no .mdev file found in this directory or any parent'
}

load_mdev_config() {
	# .mdev is a trusted shell script — sourcing is intentional (same pattern as dev's .dev config)
	# shellcheck source=/dev/null
	source "$MDEV_ROOT/.mdev"
	[[ -z "${MDEV_NAME:-}" ]] && die 'MDEV_NAME is not set in .mdev'
	MDEV_SERVICES="${MDEV_SERVICES:-}"
	export MDEV_NAME MDEV_SERVICES
}

check_docker() {
	command -v docker &>/dev/null || error 'docker is not installed or not in PATH'
}

# ---------------------------------------------------------------------------
# Service discovery
# ---------------------------------------------------------------------------

_list_service_names() {
	if [[ -n "${MDEV_SERVICES:-}" ]]; then
		local s
		while IFS=',' read -ra parts; do
			for s in "${parts[@]}"; do
				s="${s#"${s%%[![:space:]]*}"}"
				s="${s%"${s##*[![:space:]]}"}"
				[[ -z "$s" ]] && continue
				echo "$s"
			done
		done <<<"$MDEV_SERVICES"
	else
		find "$MDEV_ROOT" -mindepth 2 -name '.dev' -type f |
			sed "s|^$MDEV_ROOT/||;s|/.dev$||" |
			sort
	fi
}

discover_services() {
	local s
	while IFS= read -r s; do
		[[ -f "$MDEV_ROOT/$s/.dev" ]] || error "service '$s' not found — no .dev at $MDEV_ROOT/$s"
		echo "$s"
	done < <(_list_service_names)
}

filter_services() {
	local all_services
	mapfile -t all_services < <(discover_services)
	if [[ ${#all_services[@]} -eq 0 ]]; then
		error 'no services found — add sub-directories with .dev files'
	fi
	if [[ $# -eq 0 ]]; then
		printf '%s\n' "${all_services[@]}"
		return
	fi
	local req found
	for req in "$@"; do
		found=false
		for svc in "${all_services[@]}"; do
			if [[ "$svc" == "$req" || "$(basename "$svc")" == "$req" ]]; then
				echo "$svc"
				found=true
				break
			fi
		done
		$found || error "unknown service '$req'"
	done
}

# ---------------------------------------------------------------------------
# Execution helpers
# ---------------------------------------------------------------------------

read_dev_var() {
	# shellcheck source=/dev/null
	(source "$MDEV_ROOT/$1/.dev" 2>/dev/null && eval "echo \"\${$2:-}\"")
}

service_repo_type() { read_dev_var "$1" DEV_REPO_TYPE; }

service_supports_cmd() {
	(cd "$MDEV_ROOT/$1" && dev supports "$2" 2>/dev/null)
}

# Palette of distinct terminal colors for service labels (suppressed when NO_COLOR is set)
if [[ -z "${NO_COLOR:-}" ]]; then
	_LABEL_COLORS=('\033[36m' '\033[35m' '\033[33m' '\033[34m' '\033[32m' '\033[31m' '\033[96m' '\033[95m')
	_LABEL_RESET='\033[0m'
else
	_LABEL_COLORS=('' '' '' '' '' '' '' '')
	_LABEL_RESET=''
fi
declare -A _LABEL_COLOR_MAP=()
_LABEL_COLOR_NEXT=0

_label_color() {
	local name="$1"
	if [[ -z "${_LABEL_COLOR_MAP[$name]+_}" ]]; then
		_LABEL_COLOR_MAP[$name]=$((_LABEL_COLOR_NEXT % ${#_LABEL_COLORS[@]}))
		((_LABEL_COLOR_NEXT++)) || true
	fi
	_LABEL_COLOR_RESULT="${_LABEL_COLORS[${_LABEL_COLOR_MAP[$name]}]}"
}

mdev_labeled() {
	local service="$1"
	shift
	local label color dev_cmd
	label="$(basename "$service")"
	_label_color "$label"
	color="$_LABEL_COLOR_RESULT"
	dev_cmd="${1:-}"
	if ! service_supports_cmd "$service" "$dev_cmd"; then
		printf "${color}[%s]${_LABEL_RESET} skipping %s (not available for %s repos)\n" \
			"$label" "$dev_cmd" "$(service_repo_type "$service")"
		return 0
	fi
	(cd "$MDEV_ROOT/$service" && dev "$@") 2>&1 | while IFS= read -r line; do
		printf "${color}[%s]${_LABEL_RESET} %s\n" "$label" "$line"
	done
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_up() {
	check_docker
	local services
	mapfile -t services < <(filter_services "$@")
	for service in "${services[@]}"; do
		info "starting $(basename "$service")"
		mdev_labeled "$service" up
	done
}

cmd_down() {
	check_docker
	local services
	mapfile -t services < <(filter_services "$@")
	for service in "${services[@]}"; do
		info "stopping $(basename "$service")"
		mdev_labeled "$service" down
	done
}

cmd_status() {
	check_docker
	local services
	mapfile -t services < <(discover_services)
	for service in "${services[@]}"; do
		local label
		label="$(basename "$service")"
		local name
		name="$(read_dev_var "$service" DEV_NAME || true)"
		if [[ -z "$name" ]]; then
			echo -e "[$label] \033[0;31merror: could not read DEV_NAME\033[0m" >&2
			continue
		fi
		local count
		count="$(docker compose --project-name "$name" ps --status running --quiet 2>/dev/null | wc -l | tr -d ' ')"
		if [[ "$count" -gt 0 ]]; then
			echo -e "[$label] \033[0;32mrunning\033[0m ($count container(s))"
		else
			echo -e "[$label] \033[0;33mstopped\033[0m"
		fi
	done
}

cmd_logs() {
	check_docker
	local follow=false
	local service_args=()
	for arg in "$@"; do
		case "$arg" in
		-f | --follow) follow=true ;;
		*) service_args+=("$arg") ;;
		esac
	done
	local services
	mapfile -t services < <(filter_services "${service_args[@]}")
	if $follow; then
		local pids=()
		for service in "${services[@]}"; do
			mdev_labeled "$service" logs -f &
			pids+=($!)
		done
		trap 'kill "${pids[@]}" 2>/dev/null; exit 0' INT TERM
		wait "${pids[@]}"
	else
		for service in "${services[@]}"; do
			mdev_labeled "$service" logs
		done
	fi
}

_run_for_services() {
	local verb="$1" label="$2"
	shift 2
	check_docker
	local services
	mapfile -t services < <(filter_services "$@")
	for service in "${services[@]}"; do
		info "$label $(basename "$service")"
		mdev_labeled "$service" "$verb"
	done
}

cmd_build() { _run_for_services build 'building' "$@"; }
cmd_lint() { _run_for_services lint 'linting' "$@"; }
cmd_format() { _run_for_services format 'formatting' "$@"; }
cmd_unit() {
	local verb='unit' label='unit testing'
	check_docker
	local services
	mapfile -t services < <(filter_services "$@")

	local prev_result="$MDEV_ROOT/out/unit-result.json"
	local prev_passed='true'
	if [[ "${CLAUDECODE:-}" == '1' && -f "$prev_result" ]]; then
		prev_passed="$(jq -r '.passed' "$prev_result")"
	fi

	local carried_entries=()
	for service in "${services[@]}"; do
		local name
		name="$(basename "$service")"
		if [[ "$prev_passed" == 'false' ]]; then
			local svc_passed
			svc_passed="$(jq -r --arg n "$name" '.services[] | select(.name==$n) | .passed' "$prev_result" 2>/dev/null || true)"
			if [[ "$svc_passed" == 'true' ]]; then
				local carried
				carried="$(jq -c --arg n "$name" '.services[] | select(.name==$n)' "$prev_result")"
				carried_entries+=("$carried")
				continue
			fi
		fi
		info "$label $name"
		mdev_labeled "$service" "$verb"
	done

	local entries=() any_failed='false'
	for entry in "${carried_entries[@]+"${carried_entries[@]}"}"; do
		entries+=("$entry")
		local ep
		ep="$(printf '%s' "$entry" | jq -r '.passed')"
		if [[ "$ep" == 'false' ]]; then
			any_failed='true'
		fi
	done
	for service in "${services[@]}"; do
		local result_file="$MDEV_ROOT/$service/out/unit-result.json"
		[[ -f "$result_file" ]] || continue
		local name passed
		name="$(basename "$service")"
		passed="$(jq -r '.passed' "$result_file")"
		if [[ "$passed" == 'false' ]]; then
			any_failed='true'
		fi
		local entry
		entry="$(jq -c --arg name "$name" '{name: $name, passed: .passed, failures: .failures}' "$result_file")"
		entries+=("$entry")
	done

	local services_json top_passed aggregated
	services_json="$(printf '%s\n' "${entries[@]+"${entries[@]}"}" | jq -sc '.')"
	if [[ "$any_failed" == 'true' ]]; then
		top_passed='false'
	else
		top_passed='true'
	fi
	aggregated="$(jq -cn --argjson s "$services_json" --argjson p "$top_passed" '{passed: $p, services: $s}')"

	mkdir -p "$MDEV_ROOT/out"
	printf '%s\n' "$aggregated" >"$MDEV_ROOT/out/unit-result.json"

	if [[ "${CLAUDECODE:-}" == '1' ]]; then
		printf '%s\n' "$aggregated"
	fi
}
cmd_check() { _run_for_services check 'checking' "$@"; }
cmd_types() { _run_for_services types 'type checking' "$@"; }
cmd_security() { _run_for_services security 'security scanning' "$@"; }
cmd_lock() { _run_for_services lock 'locking' "$@"; }
cmd_ci() {
	local ref="${1:-}"
	local changed
	mapfile -t changed < <(cmd_changed ${ref:+"$ref"})

	local build_pkgs=() checks_include=() coverage_pkgs=()

	for pkg in "${changed[@]}"; do
		local output
		output="$(cd "$MDEV_ROOT/$pkg" && GITHUB_OUTPUT='' dev ci "$pkg")"

		local item
		while IFS= read -r item; do
			[[ -n "$item" ]] && build_pkgs+=("$item")
		done < <(printf '%s\n' "$output" | grep '^build=' | cut -d= -f2- | jq -r '.[]' 2>/dev/null || true)

		while IFS= read -r item; do
			[[ -n "$item" ]] && checks_include+=("$item")
		done < <(printf '%s\n' "$output" | grep '^checks=' | cut -d= -f2- | jq -c '.include[]' 2>/dev/null || true)

		while IFS= read -r item; do
			[[ -n "$item" ]] && coverage_pkgs+=("$item")
		done < <(printf '%s\n' "$output" | grep '^coverage=' | cut -d= -f2- | jq -r '.[]' 2>/dev/null || true)
	done

	local build_json checks_json coverage_json
	build_json="$(jq -cn '$ARGS.positional' --args "${build_pkgs[@]+"${build_pkgs[@]}"}")"
	coverage_json="$(jq -cn '$ARGS.positional' --args "${coverage_pkgs[@]+"${coverage_pkgs[@]}"}")"
	checks_json="$(printf '%s\n' "${checks_include[@]+"${checks_include[@]}"}" | jq -sc '{include: .}')"

	if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
		{
			printf 'build=%s\n' "$build_json"
			printf 'checks=%s\n' "$checks_json"
			printf 'coverage=%s\n' "$coverage_json"
		} >>"$GITHUB_OUTPUT"
	else
		printf 'build=%s\n' "$build_json"
		printf 'checks=%s\n' "$checks_json"
		printf 'coverage=%s\n' "$coverage_json"
	fi
}
cmd_rebuild() { _run_for_services rebuild 'rebuilding' "$@"; }
cmd_db_migrate() { _run_for_services db-migrate 'migrating' "$@"; }
cmd_push() { _run_for_services push 'pushing' "$@"; }

_run_interactive() {
	local dev_cmd="$1" service="${2:-}"
	[[ -z "$service" ]] && error "usage: mdev $dev_cmd <service>"
	local resolved
	resolved="$(filter_services "$service")"
	check_docker
	(cd "$MDEV_ROOT/$resolved" && dev "$dev_cmd")
}

cmd_shell() { _run_interactive shell "$@"; }
cmd_db_shell() { _run_interactive db-shell "$@"; }

cmd_changed() {
	local ref="${1:-}"
	command -v git &>/dev/null || error 'git is not installed'
	if [[ -z "$ref" ]]; then
		local head origin_main
		head="$(git -C "$MDEV_ROOT" rev-parse HEAD 2>/dev/null)"
		origin_main="$(git -C "$MDEV_ROOT" rev-parse origin/main 2>/dev/null || true)"
		if [[ -n "$origin_main" && "$head" == "$origin_main" ]]; then
			ref='HEAD~1'
		else
			ref='origin/main'
		fi
	fi
	local changed_files
	if [[ -z "${1:-}" && -z "${CI:-}" ]]; then
		mapfile -t changed_files < <(git -C "$MDEV_ROOT" diff --name-only HEAD 2>/dev/null || true)
	else
		git -C "$MDEV_ROOT" rev-parse "$ref" &>/dev/null || error "git ref '$ref' not found"
		mapfile -t changed_files < <(git -C "$MDEV_ROOT" diff --name-only "$ref"...HEAD 2>/dev/null || true)
	fi
	if [[ ${#changed_files[@]} -eq 0 ]]; then
		return 0
	fi
	local services
	mapfile -t services < <(discover_services)
	for file in "${changed_files[@]}"; do
		if [[ "$file" == .github/workflows/* ]]; then
			printf '%s\n' "${services[@]}"
			return 0
		fi
	done
	local -A seen=()
	local svc file
	for file in "${changed_files[@]}"; do
		for svc in "${services[@]}"; do
			if [[ "$file" == "$svc/"* || "$file" == "$svc" ]]; then
				if [[ -z "${seen[$svc]:-}" ]]; then
					echo "$svc"
					seen[$svc]=1
				fi
			fi
		done
	done
}

cmd_run() {
	local service="${1:-}"
	[[ -z "$service" ]] && error 'usage: mdev run <service> <command> [args]'
	local dev_cmd="${2:-}"
	[[ -z "$dev_cmd" ]] && error 'usage: mdev run <service> <command> [args]'
	shift 2
	local resolved
	resolved="$(filter_services "$service")"
	check_docker
	mdev_labeled "$resolved" "$dev_cmd" "$@"
}

cmd_init() {
	[[ -f "$PWD/.mdev" ]] && die '.mdev already exists in this directory'
	cat >"$PWD/.mdev" <<'EOF'
MDEV_NAME=myapp
# MDEV_SERVICES=api,frontend,worker
EOF
	echo 'wrote .mdev — edit it to configure your workspace'
}

cmd_diagnose() {
	local failed=0

	# Workspace checks
	local services=() s
	while IFS= read -r s; do
		if [[ -f "$MDEV_ROOT/$s/.dev" ]]; then
			services+=("$s")
		else
			echo -e "[${MDEV_NAME}] \033[0;31mservice '$s' not found — no .dev at $MDEV_ROOT/$s\033[0m" >&2
			failed=1
		fi
	done < <(_list_service_names)

	if [[ ${#services[@]} -eq 0 ]]; then
		echo -e "[${MDEV_NAME}] \033[0;31mno services found — add sub-directories with .dev files\033[0m" >&2
		return 1
	fi

	[[ $failed -ne 0 ]] && return 1

	# Run system checks once from workspace root
	dev diagnose || failed=1

	# Delegate repo checks to each service
	local svc
	for svc in "${services[@]}"; do
		info "diagnosing $svc"
		(
			cd "$MDEV_ROOT/$svc"
			dev diagnose --repo-only 2>&1 | sed "s/^/[${svc}] /"
		) || failed=1
	done

	return $failed
}

MDEV_COMMANDS=(up down status logs build lint format unit types security lock check ci rebuild db-migrate push shell db-shell changed run init diagnose help)

cmd_arg_type() {
	case "$1" in
	up | down | build | lint | format | unit | types | security | lock | check | rebuild | db-migrate | push) echo 'services' ;;
	ci) echo 'ref' ;;
	shell | db-shell) echo 'service' ;;
	logs) echo 'logs' ;;
	changed) echo 'changed' ;;
	run) echo 'run' ;;
	*) echo 'none' ;;
	esac
}

cmd_completions() {
	echo "${MDEV_COMMANDS[*]}"
}

cmd_help() {
	cat <<EOF
mdev $VERSION — monorepo orchestration for dev

USAGE
    mdev <command> [service...] [args]

COMMANDS
    up [services...]        Start all or specified services
    down [services...]      Stop all or specified services
    status                  Show running/stopped state per service
    logs [-f] [services...] Show service logs (use -f to follow)
    build [services...]     Build Docker images for services
    lint [services...]      Run lint in each service
    format [services...]    Run format in each service
    unit [services...]      Run unit tests in each service
    types [services...]     Run static type checking in each service
    security [services...]  Run security scanning in each service
    lock [services...]      Regenerate lock file in each service
    check [services...]     Run full quality check in each service
    ci [ref]                Emit GHA matrix outputs for changed packages
    rebuild [services...]   Build images and start services
    db-migrate [services...] Run database migrations in each service
    push [services...]      Push built image(s) to registry
    shell <service>         Open a shell in a running service container
    db-shell <service>      Open a shell in a running database container
    changed [ref]           List services changed since ref (default: origin/main, or HEAD~1 on main)
    run <service> <cmd>     Run a dev command in a specific service
    init                    Scaffold a .mdev file in the current directory
    diagnose                Check workspace and service configuration
    help                    Show this help

EOF
	if [[ -n "${MDEV_ROOT:-}" ]]; then
		local services
		mapfile -t services < <(discover_services 2>/dev/null || true)
		cat <<EOF
WORKSPACE ROOT
    $MDEV_ROOT
SERVICES
    ${services[*]:-none discovered}

EOF
	fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
	[[ "${1:-}" == 'completions' ]] && {
		cmd_completions
		exit 0
	}
	[[ "${1:-}" == 'cmd_arg_type' ]] && {
		cmd_arg_type "${2:-}"
		exit 0
	}
	[[ "${1:-}" == 'init' ]] && {
		cmd_init
		exit 0
	}
	[[ "${1:-}" == 'services' ]] && {
		MDEV_ROOT="$(find_mdev_root 2>/dev/null)" || exit 0
		load_mdev_config
		discover_services 2>/dev/null
		exit 0
	}

	MDEV_ROOT="$(find_mdev_root)"
	load_mdev_config

	local command="${1:-help}"
	shift || true

	case "$command" in
	help | -h | --help) cmd_help ;;
	up) cmd_up "$@" ;;
	down) cmd_down "$@" ;;
	status) cmd_status ;;
	logs) cmd_logs "$@" ;;
	build) cmd_build "$@" ;;
	lint) cmd_lint "$@" ;;
	format) cmd_format "$@" ;;
	unit) cmd_unit "$@" ;;
	types) cmd_types "$@" ;;
	security) cmd_security "$@" ;;
	lock) cmd_lock "$@" ;;
	check) cmd_check "$@" ;;
	ci) cmd_ci "$@" ;;
	rebuild) cmd_rebuild "$@" ;;
	db-migrate) cmd_db_migrate "$@" ;;
	push) cmd_push "$@" ;;
	shell) cmd_shell "$@" ;;
	db-shell) cmd_db_shell "$@" ;;
	changed) cmd_changed "$@" ;;
	run) cmd_run "$@" ;;
	diagnose) cmd_diagnose ;;
	*)
		echo "error: unknown command '$command'" >&2
		cmd_help
		exit 1
		;;
	esac
}

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then main "$@"; fi
