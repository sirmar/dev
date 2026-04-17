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
	$quiet && flags+=(-q)
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
	if [[ -n "${CI:-}" ]]; then
		local scope="${DEV_NAME}${stage:+-${stage}}"
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
	local network_flag=()
	[[ -n "$DEV_NETWORK" ]] && network_flag=(--network "$DEV_NETWORK")
	# shellcheck disable=SC2046
	docker run --rm --name "$(image_name "$stage")" "${network_flag[@]}" -v "$ROOT_DIR/src:/workspace/src" -v "$ROOT_DIR/out:/workspace/out" $(extra_mount_flags) "$(image_name "$stage")" "$@"
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
		info "running $label on $1"
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
	local fn="$1"
	if ! "$fn" run --rm e2e; then
		[[ -n "${CI:-}" ]] && "$fn" logs
		return 1
	fi
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
		if [[ -n "${CI:-}" && -n "$DEV_REGISTRY" && -n "${GITHUB_SHA:-}" ]]; then
			local remote="${DEV_REGISTRY}/${DEV_NAME}:${GITHUB_SHA}"
			cmd_login
			info "pushing $remote"
			docker tag "$DEV_NAME" "$remote"
			docker push "$remote"
		fi
	fi
}

cmd_login() {
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

cmd_unit() {
	run_stage unit "unit tests"
}

cmd_coverage() {
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
	run_stage types "types"
}

cmd_security() {
	run_stage security "security"
}

cmd_check() {
	cmd_lint_dockerfile
	cmd_format "$@"
	cmd_lint "$@"
	cmd_types "$@"
	! is_repo_type e2e && cmd_coverage "$@"
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
	assert_db
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
	if ! has_dockerfile_stage e2e; then
		info "no 'e2e' stage found in Dockerfile — skipping"
		return 0
	fi
	if [[ ! -f "$ROOT_DIR/docker-compose.e2e.yml" ]]; then
		info "no docker-compose.e2e.yml found — skipping e2e"
		return 0
	fi
	compose_e2e down -v
	build_image e2e true
	info "running e2e tests"
	run_compose_suite compose_e2e
}

cmd_shell() {
	if ! docker ps --format '{{.Names}}' | grep -qx "$DEV_CONTAINER"; then
		error "container '$DEV_CONTAINER' is not running — start it with: dev up"
	fi
	info "entering $DEV_CONTAINER"
	docker exec -it "$DEV_CONTAINER" bash
}

cmd_watch() {
	if ! has_dockerfile_stage watch; then
		info "no 'watch' stage found in Dockerfile — skipping"
		return 0
	fi
	build_image watch true
	info "starting watch"
	ensure_network
	local port_flag=() network_flag=()
	[[ -n "$DEV_PORT" ]] && port_flag=(-p "${DEV_PORT}:${DEV_PORT}")
	[[ -n "$DEV_NETWORK" ]] && network_flag=(--network "$DEV_NETWORK")
	# shellcheck disable=SC2046
	docker run --rm -it --name "$(image_name watch)" "${port_flag[@]}" "${network_flag[@]}" -v "$ROOT_DIR/src:/workspace/src" $(extra_mount_flags) "$(image_name watch)"
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
	build_image prod true
	info "running $DEV_NAME"
	ensure_network
	local network_flag=() port_flag=() tty_flag=()
	[[ -n "$DEV_NETWORK" ]] && network_flag=(--network "$DEV_NETWORK")
	[[ -n "$DEV_PORT" ]] && port_flag=(-p "${DEV_PORT}:${DEV_PORT}")
	[[ -t 0 ]] && tty_flag=(-it)
	# shellcheck disable=SC2046
	docker run --rm "${tty_flag[@]}" --name "$(image_name prod)" "${network_flag[@]}" "${port_flag[@]}" -v "$ROOT_DIR/src:/workspace/src" $(extra_mount_flags) "$(image_name prod)" "$@"
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
    coverage            Run tests with coverage report
    types               Run static type checking
    security            Run security scanning
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

is_repo_type() {
	local type
	for type in "$@"; do
		[[ "$DEV_REPO_TYPE" == "$type" ]] && return 0
	done
	return 1
}

assert_repo_type() {
	local command="$1"
	shift
	is_repo_type "$@" || error "'$command' is not available for $DEV_REPO_TYPE repos"
}

cmd_completions() {
	local dir="$PWD" repo_type="" dev_scripts=""
	while [[ "$dir" != "/" ]]; do
		if [[ -f "$dir/.dev" ]]; then
			repo_type="$(grep -m1 '^DEV_REPO_TYPE=' "$dir/.dev" | cut -d= -f2)"
			dev_scripts="$(grep -m1 '^DEV_SCRIPTS=' "$dir/.dev" | cut -d= -f2- | tr -d '"' || true)"
			break
		fi
		dir="$(dirname "$dir")"
	done

	local cmds="init build lint lint-dockerfile login push release help"
	if [[ "$repo_type" == "service" || "$repo_type" == "tool" || "$repo_type" == "library" ]]; then
		cmds="$cmds format unit coverage types security check"
	fi
	if [[ "$repo_type" == "service" || "$repo_type" == "tool" ]]; then
		cmds="$cmds e2e"
	fi
	if [[ "$repo_type" == "e2e" ]]; then
		cmds="$cmds format types security check"
	fi
	if [[ "$repo_type" == "tool" || "$repo_type" == "e2e" ]]; then
		cmds="$cmds run"
	fi
	if [[ -n "$dev_scripts" ]]; then
		cmds="$cmds exec"
	fi
	if [[ "$repo_type" == "service" ]]; then
		cmds="$cmds watch shell up down clean logs db-shell db-migrate"
	fi
	echo "$cmds"
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

	case "$command" in
	build | login | push | lint | lint-dockerfile | format | unit | e2e | check | coverage | types | security | watch | shell | run | exec | up | down | clean | logs | db-shell | db-migrate) ;;
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
		assert_repo_type format service tool library e2e
		cmd_format "$@"
		;;
	unit)
		assert_repo_type unit service tool library
		cmd_unit "$@"
		;;
	e2e)
		assert_repo_type e2e service tool
		cmd_e2e "$@"
		;;
	check)
		assert_repo_type check service tool library e2e
		cmd_check "$@"
		;;
	coverage)
		assert_repo_type coverage service tool library
		cmd_coverage "$@"
		;;
	types)
		assert_repo_type types service tool library e2e
		cmd_types "$@"
		;;
	security)
		assert_repo_type security service tool library e2e
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
		assert_repo_type run tool e2e
		cmd_run "$@"
		;;
	exec)
		assert_repo_type exec service tool e2e
		cmd_exec "$@"
		;;
	up)
		assert_repo_type up service
		cmd_up "$@"
		;;
	down)
		assert_repo_type down service
		cmd_down "$@"
		;;
	clean)
		assert_repo_type clean service
		cmd_clean "$@"
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
	esac
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
