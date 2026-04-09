#!/usr/bin/env bash
set -euo pipefail

VERSION="0.1.0"
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
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
	[[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/dev/config" ]] && source "${XDG_CONFIG_HOME:-$HOME/.config}/dev/config"
	# shellcheck source=/dev/null
	source "$ROOT_DIR/.dev"
	[[ -z "${DEV_NAME:-}" ]] && error "DEV_NAME is not set in .dev"
	DEV_CONTEXT="${DEV_CONTEXT:-.}"
	[[ -z "${DEV_REPO_TYPE:-}" ]] && error "DEV_REPO_TYPE is not set in .dev"
	DEV_REGISTRY="${DEV_REGISTRY:-}"
	DEV_REGISTRY_USER="${DEV_REGISTRY_USER:-}"
	DEV_REGISTRY_TOKEN="${DEV_REGISTRY_TOKEN:-}"
	DEV_NETWORK="${DEV_NETWORK:-}"
	DEV_DB_NAME="${DEV_DB_NAME:-}"
	DEV_DB_USER="${DEV_DB_USER:-root}"
	DEV_DB_PASSWORD="${DEV_DB_PASSWORD:-}"
	# Derived names
	DEV_IMAGE="${DEV_NAME}"
	DEV_E2E_IMAGE="${DEV_NAME}-e2e"
	DEV_COVERAGE_IMAGE="${DEV_NAME}-coverage"
	DEV_CONTAINER="${DEV_NAME}"
	DEV_DB_CONTAINER="${DEV_NAME}-db"
	DEV_E2E_CONTAINER="${DEV_NAME}-e2e"
	DEV_E2E_DB_CONTAINER="${DEV_NAME}-db-e2e"
	DEV_COVERAGE_CONTAINER="${DEV_NAME}-coverage"
	DEV_E2E_NETWORK="${DEV_NAME}-e2e"
	export DEV_NAME DEV_CONTEXT DEV_REPO_TYPE DEV_REGISTRY DEV_REGISTRY_USER DEV_REGISTRY_TOKEN DEV_NETWORK DEV_DB_NAME DEV_DB_USER DEV_DB_PASSWORD
	export DEV_IMAGE DEV_E2E_IMAGE DEV_COVERAGE_IMAGE DEV_CONTAINER DEV_DB_CONTAINER DEV_E2E_CONTAINER DEV_E2E_DB_CONTAINER DEV_COVERAGE_CONTAINER DEV_E2E_NETWORK
}

# ---------------------------------------------------------------------------
# Docker helpers
# ---------------------------------------------------------------------------

check_docker() {
	command -v docker &>/dev/null || error "docker is not installed or not in PATH"
}

image_name() {
	if [[ "$1" == "prod" ]]; then
		echo "$DEV_IMAGE"
	elif [[ "$1" == "e2e" ]]; then
		echo "$DEV_E2E_IMAGE"
	elif [[ "$1" == "coverage" ]]; then
		echo "$DEV_COVERAGE_IMAGE"
	else
		echo "${DEV_NAME}-${1}"
	fi
}

ensure_network() {
	if [[ -z "$DEV_NETWORK" ]]; then return 0; fi
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
	if [[ -n "$stage" ]]; then
		info "building stage $stage"
		docker build "${flags[@]}" --target "$stage" -t "$(image_name "$stage")" -f "$ROOT_DIR/Dockerfile" "$ROOT_DIR/$DEV_CONTEXT"
	else
		info "building image"
		docker build "${flags[@]}" -t "$DEV_NAME" -f "$ROOT_DIR/Dockerfile" "$ROOT_DIR/$DEV_CONTEXT"
	fi
}

run_in() {
	local stage="$1"
	shift
	docker run --rm --name "$(image_name "$stage")" -v "$ROOT_DIR:/workspace" "$(image_name "$stage")" "$@"
}

compose() {
	docker compose --project-name "$DEV_NAME" -f "$ROOT_DIR/docker-compose.yml" -f "$SCRIPT_DIR/docker-compose.network.yml" "$@"
}

compose_e2e() {
	docker compose --project-name "$DEV_E2E_NETWORK" -f "$ROOT_DIR/docker-compose.e2e.yml" "$@"
}

# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

dockerfile_stages() {
	sed -n 's/^FROM .* AS \([a-zA-Z0-9_]*\)$/\1/p' "$ROOT_DIR/Dockerfile" | grep -v '^base$'
}

cmd_build() {
	check_docker
	if [[ "$DEV_REPO_TYPE" == "image" ]]; then
		local stages
		mapfile -t stages < <(dockerfile_stages)
		if [[ ${#stages[@]} -eq 0 ]]; then
			build_image ""
		else
			has_dockerfile_stage base && build_image base
			for stage in "${stages[@]}"; do
				build_image "$stage"
			done
		fi
	else
		build_image prod
	fi
}

cmd_login() {
	check_docker
	local host user token
	if [[ -n "${CI:-}" && -n "${GITHUB_TOKEN:-}" ]]; then
		host="ghcr.io"
		user="$GITHUB_ACTOR"
		token="$GITHUB_TOKEN"
	elif command -v gh &>/dev/null && gh auth status &>/dev/null; then
		host="ghcr.io"
		user="$(gh api user --jq .login)"
		token="$(gh auth token)"
	elif [[ -n "$DEV_REGISTRY" && -n "$DEV_REGISTRY_USER" && -n "$DEV_REGISTRY_TOKEN" ]]; then
		host="${DEV_REGISTRY%%/*}"
		user="$DEV_REGISTRY_USER"
		token="$DEV_REGISTRY_TOKEN"
	else
		error "no credentials found — run 'gh auth login' or set DEV_REGISTRY, DEV_REGISTRY_USER, and DEV_REGISTRY_TOKEN in ~/.config/dev/config"
	fi
	info "logging in to $host"
	echo "$token" | docker login "$host" -u "$user" --password-stdin
}

cmd_push() {
	check_docker
	if [[ -z "$DEV_REGISTRY" ]]; then error "DEV_REGISTRY is not set — add it to .dev or ~/.config/dev/config"; fi
	cmd_login
	local tag remote
	tag="$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null || error "no git tag found — run dev release first")"
	if [[ "$DEV_REPO_TYPE" == "image" ]]; then
		remote="${DEV_REGISTRY}/${DEV_NAME}:${tag}"
		info "pushing $remote"
		docker tag "$DEV_NAME" "$remote"
		docker push "$remote"
	else
		remote="${DEV_REGISTRY}/${DEV_NAME}:${tag}"
		info "pushing $remote"
		docker tag "$(image_name prod)" "$remote"
		docker push "$remote"
	fi
}

cmd_lint_dockerfiles() {
	if [[ ! -f "$ROOT_DIR/Dockerfile" ]]; then return 0; fi
	info "linting Dockerfile"
	docker run --rm \
		-v "$ROOT_DIR:/workspace" \
		hadolint/hadolint \
		hadolint /workspace/Dockerfile
}

cmd_lint() {
	check_docker
	if [[ "$DEV_REPO_TYPE" == "image" ]]; then
		if [[ "${2:-}" != "--claude" ]]; then cmd_lint_dockerfiles; fi
		return 0
	fi
	local target=""
	if [[ "${2:-}" == "--claude" ]]; then
		local abs
		abs="$(jq -r '.tool_input.file_path')"
		target="${abs#"$ROOT_DIR"/}"
	else
		target="${2:-}"
	fi
	if has_dockerfile_stage lint; then
		build_image lint true
		if [[ "${2:-}" == "--claude" ]]; then
			info "running lint on $target"
			local output
			output="$(run_in lint "$target" 2>&1)" || {
				tail -n 20 <<<"$output" >&2
				exit 2
			}
		else
			if [[ -n "$target" ]]; then info "running lint on $target"; else info "running lint"; fi
			run_in lint ${target:+"$target"}
		fi
	else
		info "no 'lint' stage found in Dockerfile — skipping"
	fi
	if [[ -z "$target" ]] && [[ "${2:-}" != "--claude" ]]; then cmd_lint_dockerfiles; fi
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
	if [[ -f "$ROOT_DIR/docker-compose.e2e.yml" ]]; then
		compose_e2e run --rm coverage
		compose_e2e down -v
	else
		run_in coverage
	fi
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

cmd_security() {
	check_docker
	if ! has_dockerfile_stage security; then
		info "no 'security' stage found in Dockerfile — skipping"
		return 0
	fi
	build_image security true
	info "running security"
	run_in security
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
	if [[ -z "$DEV_DB_NAME" ]]; then error "DEV_DB_NAME is not set in .dev"; fi
	info "entering database on $DEV_DB_CONTAINER"
	docker exec -it "$DEV_DB_CONTAINER" mysql -u "$DEV_DB_USER" -p"$DEV_DB_PASSWORD" "$DEV_DB_NAME"
}

cmd_db_migrate() {
	check_docker
	if [[ -z "$DEV_DB_NAME" ]]; then error "DEV_DB_NAME is not set in .dev"; fi
	local db_url="mysql://${DEV_DB_USER}:${DEV_DB_PASSWORD}@${DEV_DB_CONTAINER}/${DEV_DB_NAME}"
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
	if ! has_dockerfile_stage e2e; then
		info "no 'e2e' stage found in Dockerfile — skipping"
		return 0
	fi
	if [[ ! -f "$ROOT_DIR/docker-compose.e2e.yml" ]]; then
		info "no docker-compose.e2e.yml found — skipping e2e"
		return 0
	fi
	build_image e2e true
	info "running e2e tests"
	compose_e2e run --rm e2e
	compose_e2e down -v
}

cmd_shell() {
	check_docker
	if ! docker ps --format '{{.Names}}' | grep -qx "$DEV_CONTAINER"; then
		error "container '$DEV_CONTAINER' is not running — start it with: dev up"
	fi
	info "entering $DEV_CONTAINER"
	docker exec -it "$DEV_CONTAINER" bash
}

cmd_watch() {
	check_docker
	if ! has_dockerfile_stage watch; then
		info "no 'watch' stage found in Dockerfile — skipping"
		return 0
	fi
	build_image watch true
	info "starting watch"
	docker run --rm -it --name "$(image_name watch)" -v "$ROOT_DIR:/workspace" "$(image_name watch)"
}

cmd_run() {
	check_docker
	build_image prod true
	shift
	run_in prod "$@"
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

cmd_logs() {
	check_docker
	compose logs "${@:2}"
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
    build               Build Docker image(s)
    lint                Lint Dockerfiles with hadolint
    login               Log in to container registry
    push                Push built image(s) to registry
    release <type>      Create release tag (major|minor|patch)
    help                Show this help
EOF

	if [[ "$DEV_REPO_TYPE" == "tool" || "$DEV_REPO_TYPE" == "service" ]]; then
		cat <<EOF

    lint [file]         Lint source files
    format [file]       Format source files
    unit                Run unit tests
    e2e                 Run e2e tests
    check               Run format, lint, types, and coverage
    coverage            Run tests with coverage report
    types               Run static type checking
    security            Run security scanning
EOF
	fi

	if [[ "$DEV_REPO_TYPE" == "service" ]]; then
		cat <<EOF
    watch               Build watch stage and run with hot reload
    shell               Open interactive shell in container
    run <cmd> [args]    Run arbitrary command in container
    up [service...]     Start services via Docker Compose
    down [args]         Stop services via Docker Compose
    logs [-f] [svc...] Show service logs (--follow to tail)
    db-shell            Enter shell in running database container
    db-migrate          Run database migrations
EOF
	fi

	cat <<EOF

PROJECT ROOT
    $ROOT_DIR
REPO TYPE
    $DEV_REPO_TYPE

EOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

assert_repo_type() {
	local command="$1"
	shift
	local allowed=("$@")
	for type in "${allowed[@]}"; do
		[[ "$DEV_REPO_TYPE" == "$type" ]] && return 0
	done
	error "'$command' is not available for $DEV_REPO_TYPE repos"
}

cmd_completions() {
	local dir="$PWD"
	local repo_type=""
	while [[ "$dir" != "/" ]]; do
		if [[ -f "$dir/.dev" ]]; then
			repo_type="$(grep -m1 '^DEV_REPO_TYPE=' "$dir/.dev" | cut -d= -f2)"
			break
		fi
		dir="$(dirname "$dir")"
	done

	local cmds="build lint login push release help"
	if [[ "$repo_type" == "service" || "$repo_type" == "tool" ]]; then
		cmds="$cmds format unit coverage types security check e2e"
	fi
	if [[ "$repo_type" == "service" ]]; then
		cmds="$cmds watch shell run up down logs db-shell db-migrate"
	fi
	echo "$cmds"
}

main() {
	[[ "${1:-}" == "completions" ]] && {
		cmd_completions
		exit 0
	}

	ROOT_DIR="$(find_root)"
	load_config

	local command="${1:-help}"
	case "$command" in
	build) cmd_build "$@" ;;
	login) cmd_login "$@" ;;
	push) cmd_push "$@" ;;
	release) cmd_release "$@" ;;
	lint) cmd_lint "$@" ;;
	format)
		assert_repo_type format service tool
		cmd_format "$@"
		;;
	unit)
		assert_repo_type unit service tool
		cmd_unit "$@"
		;;
	e2e)
		assert_repo_type e2e service tool
		cmd_e2e "$@"
		;;
	check)
		assert_repo_type check service tool
		cmd_check "$@"
		;;
	coverage)
		assert_repo_type coverage service tool
		cmd_coverage "$@"
		;;
	types)
		assert_repo_type types service tool
		cmd_types "$@"
		;;
	security)
		assert_repo_type security service tool
		cmd_security "$@"
		;;
	watch)
		assert_repo_type watch service
		cmd_watch "$@"
		;;
	shell)
		assert_repo_type shell service
		cmd_shell "$@"
		;;
	run)
		assert_repo_type run service
		cmd_run "$@"
		;;
	up)
		assert_repo_type up service
		cmd_up "$@"
		;;
	down)
		assert_repo_type down service
		cmd_down "$@"
		;;
	logs)
		assert_repo_type logs service
		cmd_logs "$@"
		;;
	db-shell)
		assert_repo_type db-shell service
		cmd_db_shell "$@"
		;;
	db-migrate)
		assert_repo_type db-migrate service
		cmd_db_migrate "$@"
		;;
	help | -h | --help) cmd_help ;;
	*)
		echo "error: unknown command '$command'" >&2
		cmd_help
		exit 1
		;;
	esac
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
