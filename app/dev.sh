#!/usr/bin/env bash
set -euo pipefail

VERSION="0.1.0"
export DOCKER_CLI_HINTS=false

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

info() {
	echo -e "[${DEV_NAME:-dev}] \033[0;32m$*\033[0m"
}

error() {
	echo -e "[${DEV_NAME:-dev}] \033[0;31m$*\033[0m" >&2
	exit 1
}

die() {
	echo -e "\033[0;31m$*\033[0m" >&2
	exit 1
}

# ---------------------------------------------------------------------------
# Core utilities
# ---------------------------------------------------------------------------

find_root() {
	local dir
	dir="$(pwd)"
	while [[ "$dir" != "/" ]]; do
		if [[ -f "$dir/.dev" ]]; then
			echo "$dir"
			return 0
		fi
		dir="$(dirname "$dir")"
	done
	error "no .dev file found in this directory or any parent"
}

load_config() {
	# shellcheck source=/dev/null
	source "$ROOT_DIR/.dev"
	DEV_NAME="${DEV_NAME:-dev}"
	DEV_SHELL="${DEV_SHELL:-sh}"
	DEV_NETWORK="${DEV_NETWORK:-}"
}

# ---------------------------------------------------------------------------
# Docker helpers
# ---------------------------------------------------------------------------

check_docker() {
	command -v docker &>/dev/null || error "docker is not installed or not in PATH"
}

image_name() {
	if [[ "$1" == "app" ]]; then
		echo "$DEV_NAME"
	else
		echo "${DEV_NAME}-${1}"
	fi
}

ensure_network() {
	[[ -z "$DEV_NETWORK" ]] && return 0
	if ! docker network inspect "$DEV_NETWORK" &>/dev/null; then
		info "creating network $DEV_NETWORK"
		docker network create "$DEV_NETWORK"
	fi
}

build_image() {
	local stage="$1" quiet="${2:-false}"
	local flags=()
	$quiet && flags+=(-q)
	info "building stage $stage"
	docker build "${flags[@]}" --target "$stage" -t "$(image_name "$stage")" "$ROOT_DIR"
}

run_in() {
	local stage="$1"
	shift
	docker run --rm --name "$(image_name "$stage")" -v "$ROOT_DIR:/workspace" "$(image_name "$stage")" "$@"
}

# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

cmd_build() {
	check_docker
	build_image app
}

cmd_lint() {
	check_docker
	build_image lint true
	local target="" claude_mode=false
	if [[ "${2:-}" == "--claude" ]]; then
		claude_mode=true
		local abs
		abs="$(jq -r '.tool_input.file_path')"
		target="${abs#"$ROOT_DIR"/}"
	else
		target="${2:-}"
	fi
	if [[ -n "$target" ]]; then info "running lint on $target"; else info "running lint"; fi
	if $claude_mode; then
		local output
		output="$(run_in lint ${target:+"$target"} 2>&1)" || {
			tail -n 20 <<<"$output" >&2
			exit 2
		}
	else
		run_in lint ${target:+"$target"}
	fi
}

cmd_fmt() {
	check_docker
	build_image format true
	local target="" claude_mode=false
	if [[ "${2:-}" == "--claude" ]]; then
		claude_mode=true
		local abs
		abs="$(jq -r '.tool_input.file_path')"
		target="${abs#"$ROOT_DIR"/}"
	else
		target="${2:-}"
	fi
	if [[ -n "$target" ]]; then info "running fmt on $target"; else info "running fmt"; fi
	if $claude_mode; then
		run_in format ${target:+"$target"} &>/dev/null || true
	else
		run_in format ${target:+"$target"}
	fi
}

cmd_unit() {
	check_docker
	build_image test true
	local claude_mode=false
	if [[ "${2:-}" == "--claude" ]]; then
		claude_mode=true
	fi
	info "running unit"
	if $claude_mode; then
		local output
		output="$(run_in test 2>&1)" || {
			tail -n 20 <<<"$output" >&2
			exit 2
		}
	else
		run_in test
	fi
}

cmd_coverage() {
	check_docker
	build_image coverage true
	info "running coverage"
	run_in coverage
}

cmd_shell() {
	check_docker
	build_image "$DEV_SERVICE" true
	info "running shell"
	docker run --rm -it --name "$(image_name "$DEV_SERVICE")" -v "$ROOT_DIR:/workspace" "$(image_name "$DEV_SERVICE")" "$DEV_SHELL"
}

cmd_run() {
	check_docker
	build_image app true
	shift
	run_in app "$@"
}

cmd_up() {
	check_docker
	ensure_network
	info "starting services"
	docker compose --project-name "$DEV_NAME" -f "$ROOT_DIR/docker-compose.yml" up -d "${@:2}"
}

cmd_down() {
	check_docker
	info "stopping services"
	docker compose --project-name "$DEV_NAME" -f "$ROOT_DIR/docker-compose.yml" down "${@:2}"
}

cmd_release() {
	local bump_type="${2:-}"
	case "$bump_type" in
	major | minor | patch) ;;
	*) error "usage: dev release <major|minor|patch>" ;;
	esac

	local current
	current="$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")"

	# Strip leading v
	local version="${current#v}"
	local major minor patch
	IFS='.' read -r major minor patch <<<"$version"

	case "$bump_type" in
	major)
		major=$((major + 1))
		minor=0
		patch=0
		;;
	minor)
		minor=$((minor + 1))
		patch=0
		;;
	patch) patch=$((patch + 1)) ;;
	esac

	local new_tag="v${major}.${minor}.${patch}"
	info "releasing $current -> $new_tag"
	git -C "$ROOT_DIR" tag -a "$new_tag" -m "Release $new_tag"
	info "created tag $new_tag — push with: git push origin $new_tag"
}

cmd_help() {
	cat <<EOF
dev $VERSION — developer lifecycle utility

USAGE
    dev <command> [args]

COMMANDS
    build               Build Docker images
    lint [file]         Lint shell files with ShellCheck
    fmt [file]          Format shell files with shfmt
    unit                Run unit tests with ShellSpec
    coverage            Run unit tests with kcov coverage report
    shell               Open interactive shell in container
    run <cmd> [args]    Run arbitrary command in container
    up [service...]     Start services via docker-compose
    down [args]         Stop services via docker-compose
    release <type>      Create release tag (major|minor|patch)
    help                Show this help

PROJECT ROOT
    $ROOT_DIR

EOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
	ROOT_DIR="$(find_root)"
	load_config

	local command="${1:-help}"
	case "$command" in
	build) cmd_build "$@" ;;
	lint) cmd_lint "$@" ;;
	fmt | format) cmd_fmt "$@" ;;
	unit | test) cmd_unit "$@" ;;
	coverage) cmd_coverage "$@" ;;
	shell) cmd_shell "$@" ;;
	run) cmd_run "$@" ;;
	up) cmd_up "$@" ;;
	down) cmd_down "$@" ;;
	release) cmd_release "$@" ;;
	help | -h | --help) cmd_help ;;
	*)
		echo "error: unknown command '$command'" >&2
		cmd_help
		exit 1
		;;
	esac
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
