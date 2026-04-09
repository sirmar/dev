#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/spec/support/helpers.sh"

setup_mock_docker_shell_running() {
    _setup_mock_project
    cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
if [ "$1" = "ps" ]; then
    echo "dev"
else
    echo "docker $*"
fi
EOF
    chmod +x "$MOCK_DIR/docker"
    export PATH="$MOCK_DIR:$PATH"
}

setup_mock_docker_shell_not_running() {
    _setup_mock_project
    cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
if [ "$1" = "ps" ]; then
    echo ""
else
    echo "docker $*"
fi
EOF
    chmod +x "$MOCK_DIR/docker"
    export PATH="$MOCK_DIR:$PATH"
}

Describe 'shell'
    Before 'setup_mock_docker_shell_running'
    After 'teardown_mock_docker'

    It 'execs into the running container'
        When run run_dev shell
        The output should include 'docker exec'
        The output should include 'dev'
        The status should be success
    End

    It 'uses bash as the shell'
        When run run_dev shell
        The output should include 'bash'
        The status should be success
    End
End

Describe 'shell when container is not running'
    Before 'setup_mock_docker_shell_not_running'
    After 'teardown_mock_docker'

    It 'errors with a helpful message'
        When run run_dev shell
        The stderr should include 'not running'
        The status should be failure
    End
End
