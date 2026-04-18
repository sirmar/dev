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

discover_services() {
	if [[ -n "${MDEV_SERVICES:-}" ]]; then
		local s
		while IFS=',' read -ra parts; do
			for s in "${parts[@]}"; do
				s="${s#"${s%%[![:space:]]*}"}"
				s="${s%"${s##*[![:space:]]}"}"
				[[ -z "$s" ]] && continue
				[[ -f "$MDEV_ROOT/$s/.dev" ]] || error "service '$s' not found — no .dev at $MDEV_ROOT/$s"
				echo "$s"
			done
		done <<<"$MDEV_SERVICES"
	else
		find "$MDEV_ROOT" -mindepth 2 -name '.dev' -type f |
			sed "s|^$MDEV_ROOT/||;s|/.dev$||" |
			sort
	fi
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
	grep -m1 "^$2=" "$MDEV_ROOT/$1/.dev" | cut -d= -f2 | tr -d '"'
}

service_repo_type() { read_dev_var "$1" DEV_REPO_TYPE; }

service_supports_cmd() {
	(cd "$MDEV_ROOT/$1" && dev completions 2>/dev/null) | grep -qw "$2"
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
cmd_unit() { _run_for_services unit 'unit testing' "$@"; }
cmd_check() { _run_for_services check 'checking' "$@"; }
cmd_types() { _run_for_services types 'type checking' "$@"; }
cmd_rebuild() { _run_for_services rebuild 'rebuilding' "$@"; }
cmd_db_migrate() { _run_for_services db-migrate 'migrating' "$@"; }

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
	local ref="${1:-origin/main}"
	command -v git &>/dev/null || error 'git is not installed'
	git -C "$MDEV_ROOT" rev-parse "$ref" &>/dev/null || error "git ref '$ref' not found"
	local changed_files
	mapfile -t changed_files < <(git -C "$MDEV_ROOT" diff --name-only "$ref"...HEAD 2>/dev/null || true)
	if [[ ${#changed_files[@]} -eq 0 ]]; then
		return 0
	fi
	local services
	mapfile -t services < <(discover_services)
	local seen=() svc file already s
	for file in "${changed_files[@]}"; do
		for svc in "${services[@]}"; do
			if [[ "$file" == "$svc/"* || "$file" == "$svc" ]]; then
				already=false
				for s in "${seen[@]+"${seen[@]}"}"; do [[ "$s" == "$svc" ]] && already=true; done
				if ! $already; then
					echo "$svc"
					seen+=("$svc")
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

cmd_completions() {
	echo 'up down status logs build lint format unit types check rebuild db-migrate shell db-shell changed run init help'
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
    check [services...]     Run full quality check in each service
    rebuild [services...]   Build images and start services
    db-migrate [services...] Run database migrations in each service
    shell <service>         Open a shell in a running service container
    db-shell <service>      Open a shell in a running database container
    changed [ref]           List services changed since ref (default: origin/main)
    run <service> <cmd>     Run a dev command in a specific service
    init                    Scaffold a .mdev file in the current directory
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
	check) cmd_check "$@" ;;
	rebuild) cmd_rebuild "$@" ;;
	db-migrate) cmd_db_migrate "$@" ;;
	shell) cmd_shell "$@" ;;
	db-shell) cmd_db_shell "$@" ;;
	changed) cmd_changed "$@" ;;
	run) cmd_run "$@" ;;
	*)
		echo "error: unknown command '$command'" >&2
		cmd_help
		exit 1
		;;
	esac
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
