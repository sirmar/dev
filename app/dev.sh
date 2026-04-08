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
	DEV_CONTEXT="${DEV_CONTEXT:-.}"
	DEV_NETWORK="${DEV_NETWORK:-}"
	DEV_DB_NAME="${DEV_DB_NAME:-}"
	DEV_DB_USER="${DEV_DB_USER:-root}"
	DEV_DB_PASSWORD="${DEV_DB_PASSWORD:-}"
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

has_dockerfile_stage() {
	local stage="$1"
	grep -qE "^FROM .+ AS ${stage}$" "$ROOT_DIR/Dockerfile" 2>/dev/null
}

build_image() {
	local stage="$1" quiet="${2:-false}"
	local flags=()
	$quiet && flags+=(-q)
	info "building stage $stage"
	docker build "${flags[@]}" --target "$stage" -t "$(image_name "$stage")" -f "$ROOT_DIR/Dockerfile" "$ROOT_DIR/$DEV_CONTEXT"
}

run_in() {
	local stage="$1"
	shift
	docker run --rm --name "$(image_name "$stage")" -v "$ROOT_DIR:/workspace" "$(image_name "$stage")" "$@"
}

compose() {
	docker compose --project-name "$DEV_NAME" -f "$ROOT_DIR/docker-compose.yml" "$@"
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
	if ! has_dockerfile_stage lint; then
		info "no 'lint' stage found in Dockerfile — skipping"
		return 0
	fi
	build_image lint true
	local target=""
	if [[ "${2:-}" == "--claude" ]]; then
		local abs
		abs="$(jq -r '.tool_input.file_path')"
		target="${abs#"$ROOT_DIR"/}"
		info "running lint on $target"
		local output
		output="$(run_in lint "$target" 2>&1)" || {
			tail -n 20 <<<"$output" >&2
			exit 2
		}
	else
		target="${2:-}"
		if [[ -n "$target" ]]; then info "running lint on $target"; else info "running lint"; fi
		run_in lint ${target:+"$target"}
	fi
}

cmd_format() {
	check_docker
	if ! has_dockerfile_stage format; then
		info "no 'format' stage found in Dockerfile — skipping"
		return 0
	fi
	build_image format true
	local target=""
	if [[ "${2:-}" == "--claude" ]]; then
		local abs
		abs="$(jq -r '.tool_input.file_path')"
		target="${abs#"$ROOT_DIR"/}"
		info "running format on $target"
		run_in format "$target" &>/dev/null || true
	else
		target="${2:-}"
		if [[ -n "$target" ]]; then info "running format on $target"; else info "running format"; fi
		run_in format ${target:+"$target"}
	fi
}

cmd_unit() {
	check_docker
	if ! has_dockerfile_stage unit; then
		info "no 'unit' stage found in Dockerfile — skipping"
		return 0
	fi
	build_image unit true
	info "running unit tests"
	if [[ "${2:-}" == "--claude" ]]; then
		local output
		output="$(run_in unit 2>&1)" || {
			tail -n 20 <<<"$output" >&2
			exit 2
		}
	else
		run_in unit
	fi
}

cmd_coverage() {
	check_docker
	if ! has_dockerfile_stage coverage; then
		info "no 'coverage' stage found in Dockerfile — skipping"
		return 0
	fi
	build_image coverage true
	info "running coverage"
	run_in coverage
}

cmd_types() {
	check_docker
	if ! has_dockerfile_stage types; then
		info "no 'types' stage found in Dockerfile — skipping"
		return 0
	fi
	build_image types true
	info "running types"
	run_in types
}

cmd_check() {
	check_docker
	cmd_format "$@"
	cmd_lint "$@"
	cmd_types "$@"
	cmd_coverage "$@"
}

cmd_db_shell() {
	check_docker
	[[ -z "$DEV_DB_NAME" ]] && error "DEV_DB_NAME is not set in .dev"
	local container="${DEV_NAME}-db"
	info "entering database on $container"
	docker exec -it "$container" mysql -u "$DEV_DB_USER" -p"$DEV_DB_PASSWORD" "$DEV_DB_NAME"
}

cmd_db_migrate() {
	check_docker
	[[ -z "$DEV_DB_NAME" ]] && error "DEV_DB_NAME is not set in .dev"
	local db_url="mysql://${DEV_DB_USER}:${DEV_DB_PASSWORD}@${DEV_NAME}-db/${DEV_DB_NAME}"
	info "running migrations"
	docker run --rm \
		--network "${DEV_NETWORK:-${DEV_NAME}_default}" \
		-v "$ROOT_DIR/migrations:/db/migrations" \
		-e "DATABASE_URL=$db_url" \
		ghcr.io/amacneil/dbmate \
		--migrations-dir /db/migrations \
		--no-dump-schema \
		up
}

cmd_e2e() {
	check_docker
	info "running e2e tests"
	shellspec spec/e2e
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
	compose up -d "${@:2}"
}

cmd_down() {
	check_docker
	info "stopping services"
	compose down "${@:2}"
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
    format [file]       Format shell files with shfmt
    unit                Run unit tests with ShellSpec
    e2e                 Run end-to-end tests against fixture projects
    check               Run format, lint, types, and coverage (stops on first failure)
    coverage            Run unit tests with kcov coverage report
    types               Run static type checking
    shell               Open interactive shell in container
    run <cmd> [args]    Run arbitrary command in container
    up [service...]     Start services via docker-compose
    down [args]         Stop services via docker-compose
    db-shell            Enter shell in running database container
    db-migrate          Run database migrations with dbmate
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
	check) cmd_check "$@" ;;
	e2e) cmd_e2e "$@" ;;
	lint) cmd_lint "$@" ;;
	format) cmd_format "$@" ;;
	unit) cmd_unit "$@" ;;
	coverage) cmd_coverage "$@" ;;
	types) cmd_types "$@" ;;
	shell) cmd_shell "$@" ;;
	run) cmd_run "$@" ;;
	up) cmd_up "$@" ;;
	down) cmd_down "$@" ;;
	db-shell) cmd_db_shell "$@" ;;
	db-migrate) cmd_db_migrate "$@" ;;
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
