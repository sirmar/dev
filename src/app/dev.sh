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

find_dev_file() {
	local dir
	dir="$(pwd)"
	ROOT_DIR=""
	while [[ "$dir" != "/" ]]; do
		if [[ -f "$dir/.dev" ]]; then
			ROOT_DIR="$dir"
			return 0
		fi
		dir="$(dirname "$dir")"
	done
}

find_root() {
	find_dev_file
	[[ -z "$ROOT_DIR" ]] && error "no .dev file found in this directory or any parent"
	echo "$ROOT_DIR"
}

load_config() {
	# shellcheck source=/dev/null
	[[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/dev/config" ]] && source "${XDG_CONFIG_HOME:-$HOME/.config}/dev/config"
	# shellcheck source=/dev/null
	source "$ROOT_DIR/.dev"
	[[ -z "${DEV_NAME:-}" ]] && error "DEV_NAME is not set in .dev"
	DEV_CONTEXT="${DEV_CONTEXT:-.}"
	[[ -z "${DEV_REPO_TYPE:-}" ]] && error "DEV_REPO_TYPE is not set in .dev"
	DEV_REGISTRY="${DEV_REGISTRY:-${GITHUB_REPOSITORY_OWNER:+ghcr.io/$GITHUB_REPOSITORY_OWNER}}"
	DEV_REGISTRY_USER="${DEV_REGISTRY_USER:-}"
	DEV_REGISTRY_TOKEN="${DEV_REGISTRY_TOKEN:-}"
	DEV_NETWORK="${DEV_NETWORK:-}"
	DEV_SCRIPTS="${DEV_SCRIPTS:-}"
	DEV_PORT="${DEV_PORT:-}"
	DEV_MOUNTS="${DEV_MOUNTS:-}"
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
	export DEV_NAME DEV_CONTEXT DEV_REPO_TYPE DEV_REGISTRY DEV_REGISTRY_USER DEV_REGISTRY_TOKEN DEV_NETWORK DEV_SCRIPTS DEV_PORT DEV_MOUNTS DEV_DB_NAME DEV_DB_USER DEV_DB_PASSWORD
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

ensure_network_exists() {
	local network="$1"
	if ! docker network inspect "$network" &>/dev/null; then
		info "creating network $network"
		docker network create "$network"
	fi
}

ensure_network() {
	[[ -z "$DEV_NETWORK" ]] && return 0
	ensure_network_exists "$DEV_NETWORK"
}

ensure_e2e_network() {
	ensure_network_exists "$DEV_E2E_NETWORK"
}

has_dockerfile_stage() {
	local stage="$1"
	grep -qE "^FROM .+ AS ${stage}$" "$ROOT_DIR/Dockerfile" 2>/dev/null
}

build_image() {
	local stage="$1" quiet="${2:-false}" no_cache="${3:-false}"
	local flags=()
	$quiet && ! in_ci && flags+=(-q)
	$no_cache && flags+=(--no-cache)
	local cmd=docker\ build target_flags=() tag
	if [[ -n "$stage" ]]; then
		info "building stage $stage"
		target_flags=(--target "$stage")
		tag="$(image_name "$stage")"
	else
		info "building image"
		tag="$DEV_NAME"
	fi
	if in_ci; then
		local scope="${DEV_NAME}${stage:+-${stage}}"
		flags+=(--cache-from "type=gha,scope=${DEV_NAME}-deps")
		flags+=(--cache-from "type=gha,scope=${scope}")
		flags+=(--cache-to "type=gha,mode=max,scope=${scope}")
		flags+=(--load)
		cmd=docker\ buildx\ build
	fi
	$cmd "${flags[@]}" "${target_flags[@]}" -t "$tag" -f "$ROOT_DIR/Dockerfile" "$ROOT_DIR/$DEV_CONTEXT"
}

extra_mount_flags() {
	mkdir -p "$ROOT_DIR/out"
	local flags=(-v "$ROOT_DIR/out:/workspace/out")
	for mount in $DEV_MOUNTS; do
		local host_path="${mount%%:*}"
		mkdir -p "$ROOT_DIR/$host_path"
		flags+=(-v "$ROOT_DIR/$host_path:${mount#*:}")
	done
	echo "${flags[@]}"
}

run_in() {
	local stage="$1"
	shift
	ensure_network
	mkdir -p "$ROOT_DIR/out"
	local network_flag=() port_flag=() tty_flag=()
	[[ -n "$DEV_NETWORK" ]] && network_flag=(--network "$DEV_NETWORK")
	[[ -n "$DEV_PORT" ]] && port_flag=(-p "${DEV_PORT}:${DEV_PORT}")
	[[ -t 0 ]] && tty_flag=(-it)
	# shellcheck disable=SC2046
	docker run --rm "${tty_flag[@]}" --name "$(image_name "$stage")" "${port_flag[@]}" "${network_flag[@]}" -v "$ROOT_DIR/src:/workspace/src" -v "$ROOT_DIR/out:/workspace/out" $(extra_mount_flags) "$(image_name "$stage")" "$@"
}

run_stage() {
	local stage="$1" label="$2"
	shift 2
	if ! has_dockerfile_stage "$stage"; then
		info "no '$stage' stage found in Dockerfile — skipping"
		return 0
	fi
	build_image "$stage" true
	if [[ $# -gt 0 ]]; then
		info "running $label in $1"
	else
		info "running $label"
	fi
	run_in "$stage" "$@"
}

compose() {
	local network_args=()
	[[ -n "$DEV_NETWORK" ]] && network_args=(-f "$SCRIPT_DIR/docker-compose.network.yml")
	docker compose --project-name "$DEV_NAME" -f "$ROOT_DIR/docker-compose.yml" "${network_args[@]}" "$@"
}

compose_e2e() {
	ensure_e2e_network
	docker compose --project-name "$DEV_E2E_NETWORK" -f "$ROOT_DIR/docker-compose.e2e.yml" -f "$SCRIPT_DIR/docker-compose.e2e-network.yml" "$@"
}

run_compose_suite() {
	local fn="$1" service="${2:-e2e}"
	if ! "$fn" run --rm "$service"; then
		in_ci && "$fn" logs
		return 1
	fi
}

run_stage_compose() {
	local stage="$1" label="$2" compose_fn="$3" compose_file="$4" compose_mode="${5:-optional}"
	shift 5
	if ! has_dockerfile_stage "$stage"; then
		info "no '$stage' stage found in Dockerfile — skipping"
		return 0
	fi
	if [[ ! -f "$compose_file" ]]; then
		if [[ "$compose_mode" == "required" ]]; then
			info "no $(basename "$compose_file") found — skipping $label"
			return 0
		fi
		build_image "$stage" true
		info "running $label"
		run_in "$stage" "$@"
		return 0
	fi
	"$compose_fn" down -v
	mkdir -p "$ROOT_DIR/$DEV_CONTEXT/out"
	build_image "$stage" true
	info "running $label"
	run_compose_suite "$compose_fn" "$stage"
}

# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

dockerfile_stages() {
	sed -n 's/^FROM .* AS \([a-zA-Z0-9_]*\)$/\1/p' "$ROOT_DIR/Dockerfile" | grep -v '^base$'
}

cmd_build() {
	local no_cache=false
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--no-cache) no_cache=true ;;
		*) echo "error: unknown flag '$1'" >&2 && exit 1 ;;
		esac
		shift
	done

	if is_repo_type library; then
		info "library repos have no prod stage — skipping build"
		return 0
	fi

	if is_repo_type image; then
		local stages
		mapfile -t stages < <(dockerfile_stages)
		if [[ ${#stages[@]} -eq 0 ]]; then
			build_image "" false "$no_cache"
		else
			has_dockerfile_stage base && build_image base false "$no_cache"
			for stage in "${stages[@]}"; do
				build_image "$stage" false "$no_cache"
			done
		fi
	else
		build_image prod false "$no_cache"
	fi
}

cmd_login() {
	local host user token
	if in_ci && [[ -n "${GITHUB_TOKEN:-}" ]]; then
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
	if [[ -z "$DEV_REGISTRY" ]]; then error "DEV_REGISTRY is not set — add it to .dev or ~/.config/dev/config"; fi
	cmd_login
	local tag remote
	tag="$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null || error "no git tag found — run dev release first")"
	remote="${DEV_REGISTRY}/${DEV_NAME}:${tag}"
	info "pushing $remote"
	docker buildx inspect dev-builder &>/dev/null || docker buildx create --name dev-builder --driver docker-container --use
	docker buildx use dev-builder
	if is_repo_type image; then
		docker buildx build --platform linux/amd64,linux/arm64 --push -t "$remote" -f "$ROOT_DIR/Dockerfile" "$ROOT_DIR/$DEV_CONTEXT"
	else
		docker buildx build --platform linux/amd64,linux/arm64 --push --target prod -t "$remote" -f "$ROOT_DIR/Dockerfile" "$ROOT_DIR/$DEV_CONTEXT"
	fi
}

cmd_lint_dockerfile() {
	if [[ ! -f "$ROOT_DIR/Dockerfile" ]]; then
		info "no Dockerfile found — skipping"
		return 0
	fi
	info "linting Dockerfile"
	docker run --rm \
		-v "$ROOT_DIR/Dockerfile:/Dockerfile:ro" \
		hadolint/hadolint:v2.14.0 \
		hadolint /Dockerfile
}

cmd_lint() {
	is_repo_type image && return 0
	run_stage lint "lint" "$@"
}

cmd_format() {
	run_stage format "format" "$@"
}

translate_paths() {
	local result=()
	for path in "$@"; do
		local abs
		if [[ "$path" = /* ]]; then
			abs="$path"
		else
			abs="$PWD/$path"
		fi
		if [[ "$abs" != "$ROOT_DIR/src/"* ]]; then
			echo "error: path must be under src/: $path" >&2
			return 1
		fi
		result+=("/workspace/${abs#"$ROOT_DIR/"}")
	done
	echo "${result[@]}"
}

cmd_unit() {
	if [[ $# -gt 0 ]]; then
		local translated
		translated=$(translate_paths "$@") || return 1
		# shellcheck disable=SC2086
		run_stage unit "unit tests" $translated
	else
		run_stage unit "unit tests"
	fi
}

cmd_coverage() {
	if [[ $# -gt 0 ]]; then
		local translated
		translated=$(translate_paths "$@") || return 1
		# shellcheck disable=SC2086
		run_stage_compose coverage "coverage" compose_e2e "$ROOT_DIR/docker-compose.e2e.yml" optional $translated
	else
		run_stage_compose coverage "coverage" compose_e2e "$ROOT_DIR/docker-compose.e2e.yml" optional
	fi
}

cmd_types() {
	run_stage types "types"
}

cmd_security() {
	run_stage security "security"
}

cmd_lock() {
	run_stage lock "lock"
	for lockfile in pnpm-lock.yaml uv.lock; do
		if [[ -f "$ROOT_DIR/out/$lockfile" ]]; then cp "$ROOT_DIR/out/$lockfile" "$ROOT_DIR/$lockfile"; fi
	done
}

cmd_check() {
	cmd_lint_dockerfile
	cmd_format "$@"
	cmd_lint "$@"
	cmd_types "$@"
	cmd_security "$@"
	if ! is_repo_type e2e; then cmd_coverage "$@"; fi
}

assert_db() {
	if [[ -z "$DEV_DB_NAME" ]]; then error "DEV_DB_NAME is not set in .dev"; fi
}

cmd_db_shell() {
	assert_db
	info "entering database on $DEV_DB_CONTAINER"
	docker exec -it "$DEV_DB_CONTAINER" mysql -u "$DEV_DB_USER" -p"$DEV_DB_PASSWORD" "$DEV_DB_NAME"
}

cmd_db_migrate() {
	[[ -z "$DEV_DB_NAME" ]] && {
		info "skipping db-migrate (DEV_DB_NAME not set)"
		return 0
	}
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
	run_stage_compose e2e "e2e tests" compose_e2e "$ROOT_DIR/docker-compose.e2e.yml" required
}

cmd_shell() {
	if ! docker ps --format '{{.Names}}' | grep -qx "$DEV_CONTAINER"; then
		error "container '$DEV_CONTAINER' is not running — start it with: dev up"
	fi
	info "entering $DEV_CONTAINER"
	docker exec -it "$DEV_CONTAINER" bash
}

cmd_watch() {
	run_stage watch "watch"
}

cmd_run() {
	if is_repo_type e2e; then
		if [[ ! -f "$ROOT_DIR/docker-compose.yml" ]]; then
			info "no docker-compose.yml found — skipping"
			return 0
		fi
		compose down -v
		info "running e2e tests"
		run_compose_suite compose
		return
	fi
	run_stage prod "$DEV_NAME" "$@"
}

cmd_exec() {
	if ! has_dockerfile_stage scripts; then
		info "no 'scripts' stage found in Dockerfile — skipping"
		return 0
	fi
	build_image scripts true
	local script="${1:-}"
	[[ -z "$script" ]] && error "usage: dev exec <script> [args]"
	shift
	local script_path=""
	for entry in $DEV_SCRIPTS; do
		local name="${entry%%:*}"
		if [[ "$name" == "$script" ]]; then
			script_path="${entry#*:}"
			break
		fi
	done
	[[ -z "$script_path" ]] && error "unknown script '$script' — available: $(echo "$DEV_SCRIPTS" | tr ' ' '\n' | cut -d: -f1 | tr '\n' ' ')"
	info "running $script"
	run_in scripts "$script_path" "$@"
}

cmd_ci() {
	cmd_build
	cmd_check "$@"
}

cmd_rebuild() {
	local no_cache=false
	[[ "${1:-}" == "--no-cache" ]] && {
		no_cache=true
		shift
	}
	local build_args=()
	$no_cache && build_args+=(--no-cache)
	cmd_build "${build_args[@]}"
	cmd_up "$@"
}

cmd_up() {
	ensure_network
	info "starting services"
	compose up -d "$@"
}

cmd_down() {
	info "stopping services"
	compose down "$@"
}

cmd_clean() {
	info "removing services and volumes"
	compose down -v
	if [[ -f "$ROOT_DIR/docker-compose.e2e.yml" ]]; then
		compose_e2e down -v
	fi
}

cmd_logs() {
	compose logs "$@"
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
    init image <n>         Scaffold a new base image project
    init <type> <lang> <n> Scaffold a new project (type: tool|service|library, lang: bash|python|typescript)
    build [--no-cache]   Build Docker image(s)
    lint                Lint source files
    lint-dockerfile     Lint Dockerfile with hadolint
    login               Log in to container registry
    push                Push built image(s) to registry
    release <type>      Create release tag (major|minor|patch)
    help                Show this help
EOF

	if is_repo_type tool service library; then
		cat <<EOF

    lint [file]         Lint source files
    format [file]       Format source files
    unit                Run unit tests
    check               Run format, lint, types, and coverage
    ci                  Build and run full quality check
    coverage            Run tests with coverage report
    types               Run static type checking
    security            Run security scanning
    lock                Regenerate lock file
EOF
	fi

	if is_repo_type tool service; then
		cat <<EOF
    e2e                 Run e2e tests
EOF
	fi

	if is_repo_type e2e; then
		cat <<EOF

    lint [file]         Lint source files
    format [file]       Format source files
    check               Run format, lint, and types
    types               Run static type checking
    security            Run security scanning
    lock                Regenerate lock file
    run                 Run e2e tests via docker-compose.yml
EOF
	fi

	if is_repo_type tool; then
		cat <<EOF
    run [args]          Run the tool
EOF
	fi

	if [[ -n "$DEV_SCRIPTS" ]]; then
		local script_names
		script_names="$(echo "$DEV_SCRIPTS" | tr ' ' '\n' | cut -d: -f1 | tr '\n' ' ' | sed 's/ $//')"
		cat <<EOF
    exec <script>       Run a script in the scripts stage ($script_names)
EOF
	fi

	if is_repo_type service; then
		cat <<EOF
    watch               Build watch stage and run with hot reload
    shell               Open interactive shell in container
    rebuild             Build image(s) and start services
    up [service...]     Start services via Docker Compose
    down [args]         Stop services via Docker Compose
    clean               Remove all containers and volumes
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

in_ci() { [[ -n "${CI:-}" ]]; }

is_repo_type() {
	local type
	for type in "$@"; do
		[[ "$DEV_REPO_TYPE" == "$type" ]] && return 0
	done
	return 1
}

cmd_args() {
	case "$1" in
	build) echo '--no-cache' ;;
	release) echo 'major minor patch' ;;
	init) echo 'tool service image library' ;;
	esac
}

cmd_repo_types() {
	case "$1" in
	init | build | lint | lint-dockerfile | login | push | release | help) echo '*' ;;
	format | check | ci | types | security | lock) echo 'service tool library e2e' ;;
	unit | coverage) echo 'service tool library' ;;
	run) echo 'tool e2e' ;;
	exec) echo 'service tool e2e' ;;
	e2e) echo 'service tool' ;;
	watch | shell | rebuild | up | down | clean | logs | db-shell | db-migrate) echo 'service' ;;
	esac
}

assert_repo_type() {
	local command="$1"
	local allowed
	allowed="$(cmd_repo_types "$command")"
	if [[ "$allowed" != '*' ]] && [[ " $allowed " != *" $DEV_REPO_TYPE "* ]]; then
		info "skipping $command (not available for $DEV_REPO_TYPE repos)"
		exit 0
	fi
}

_DEV_COMMANDS=(init build lint lint-dockerfile login push release help
	format unit e2e check ci coverage types security lock
	watch shell run exec rebuild up down clean logs db-shell db-migrate)

cmd_completions() {
	find_dev_file
	local DEV_REPO_TYPE="" DEV_SCRIPTS=""
	# shellcheck source=/dev/null
	[[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/dev/config" ]] && source "${XDG_CONFIG_HOME:-$HOME/.config}/dev/config"
	# shellcheck source=/dev/null
	[[ -n "$ROOT_DIR" ]] && source "$ROOT_DIR/.dev"

	local cmds="" cmd allowed
	for cmd in "${_DEV_COMMANDS[@]}"; do
		if [[ "$cmd" == "exec" ]]; then
			[[ -n "$DEV_SCRIPTS" ]] && cmds="$cmds $cmd"
			continue
		fi
		allowed="$(cmd_repo_types "$cmd")"
		if [[ "$allowed" == '*' ]] || [[ " $allowed " == *" $DEV_REPO_TYPE "* ]]; then
			cmds="$cmds $cmd"
		fi
	done
	echo "${cmds# }"
}

cmd_init() {
	local repo_type="${1:-}" language="${2:-}" name="${3:-}"
	[[ -z "$repo_type" ]] && error "usage: dev init image <name>  |  dev init <type> <language> <name>"
	local template_dir label
	if [[ "$repo_type" == "image" ]]; then
		[[ -z "$language" ]] && error "usage: dev init image <name>"
		name="$language"
		template_dir="$SCRIPT_DIR/init/image"
		label="image"
	else
		[[ -z "$language" || -z "$name" ]] && error "usage: dev init <type> <language> <name>"
		case "$repo_type" in
		tool | service | library) ;;
		*) error "unknown repo-type '$repo_type' (tool|service|library|image)" ;;
		esac
		case "$language" in
		bash) [[ "$repo_type" == "tool" ]] || error "bash is only supported for tool repos" ;;
		python) ;;
		typescript) [[ "$repo_type" == "service" ]] || error "typescript is only supported for service repos" ;;
		*) error "unknown language '$language' (bash|python|typescript)" ;;
		esac
		template_dir="$SCRIPT_DIR/init/$language/$repo_type"
		label="$language/$repo_type"
	fi

	local dev_version
	dev_version=$(git -C "$SCRIPT_DIR" describe --tags --abbrev=0 2>/dev/null || echo "latest")

	while IFS= read -r -d '' src; do
		local rel="${src#"$template_dir/"}"
		local dst
		case "$rel" in
		dev.tmpl) dst=".dev" ;;
		Dockerfile.tmpl) dst="Dockerfile" ;;
		*) dst="$rel" ;;
		esac
		mkdir -p "$(dirname "$dst")"
		if [[ -e "$dst" ]]; then
			info "skip $dst"
		else
			sed -e "s/{{DEV_NAME}}/$name/g" -e "s/{{DEV_VERSION}}/$dev_version/g" "$src" >"$dst"
			info "write $dst"
		fi
	done < <(find "$template_dir" -type f -print0)

	find src/app -name "*.sh" -type f -print0 2>/dev/null | xargs -r -0 chmod +x || true
	info "initialized $name ($label)"
	info "next: dev build"
}

main() {
	[[ "${1:-}" == "completions" ]] && {
		cmd_completions
		exit 0
	}
	[[ "${1:-}" == "cmd_args" ]] && {
		shift
		cmd_args "$@"
		exit 0
	}
	[[ "${1:-}" == "supports" ]] && {
		ROOT_DIR="$(find_root)"
		load_config
		local allowed
		allowed="$(cmd_repo_types "${2:-}")"
		if [[ "$allowed" == '*' ]] || [[ " $allowed " == *" $DEV_REPO_TYPE "* ]]; then exit 0; else exit 1; fi
	}
	[[ "${1:-}" == "list-scripts" ]] && {
		find_dev_file
		local DEV_SCRIPTS=""
		# shellcheck source=/dev/null
		[[ -n "$ROOT_DIR" ]] && source "$ROOT_DIR/.dev"
		echo "$DEV_SCRIPTS" | tr ' ' '\n' | cut -d: -f1 | grep -v '^$' || true
		exit 0
	}
	[[ "${1:-}" == "init" ]] && {
		shift
		cmd_init "$@"
		exit 0
	}

	ROOT_DIR="$(find_root)"
	load_config

	local command="${1:-help}"
	case "$command" in
	help | -h | --help)
		cmd_help
		return
		;;
	release)
		cmd_release "$@"
		return
		;;
	esac

	[[ "$command" == "translate_paths" ]] && {
		shift
		translate_paths "$@"
		return
	}

	case "$command" in
	build | login | push | lint | lint-dockerfile | format | unit | e2e | check | ci | coverage | types | security | lock | watch | shell | run | exec | rebuild | up | down | clean | logs | db-shell | db-migrate) ;;
	*)
		echo "error: unknown command '$command'" >&2
		cmd_help
		exit 1
		;;
	esac

	check_docker

	shift
	case "$command" in
	build) cmd_build "$@" ;;
	login) cmd_login "$@" ;;
	push) cmd_push "$@" ;;
	lint) cmd_lint "$@" ;;
	lint-dockerfile) cmd_lint_dockerfile ;;
	format)
		assert_repo_type format
		cmd_format "$@"
		;;
	unit)
		assert_repo_type unit
		cmd_unit "$@"
		;;
	e2e)
		assert_repo_type e2e
		cmd_e2e "$@"
		;;
	check)
		assert_repo_type check
		cmd_check "$@"
		;;
	ci)
		assert_repo_type ci
		cmd_ci "$@"
		;;
	coverage)
		assert_repo_type coverage
		cmd_coverage "$@"
		;;
	types)
		assert_repo_type types
		cmd_types "$@"
		;;
	security)
		assert_repo_type security
		cmd_security "$@"
		;;
	lock)
		assert_repo_type lock
		cmd_lock "$@"
		;;
	watch)
		assert_repo_type watch
		cmd_watch "$@"
		;;
	shell)
		assert_repo_type shell
		cmd_shell "$@"
		;;
	run)
		assert_repo_type run
		cmd_run "$@"
		;;
	exec)
		assert_repo_type exec
		cmd_exec "$@"
		;;
	rebuild)
		assert_repo_type rebuild
		cmd_rebuild "$@"
		;;
	up)
		assert_repo_type up
		cmd_up "$@"
		;;
	down)
		assert_repo_type down
		cmd_down "$@"
		;;
	clean)
		assert_repo_type clean
		cmd_clean "$@"
		;;
	logs)
		assert_repo_type logs
		cmd_logs "$@"
		;;
	db-shell)
		assert_repo_type db-shell
		cmd_db_shell "$@"
		;;
	db-migrate)
		assert_repo_type db-migrate
		cmd_db_migrate "$@"
		;;
	esac
}

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then main "$@"; fi
