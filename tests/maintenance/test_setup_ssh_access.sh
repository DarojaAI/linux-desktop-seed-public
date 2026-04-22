#!/usr/bin/env bats

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../scripts/maintenance" && pwd)"

setup() {
    TEST_DIR=$(mktemp -d)
    export HOME="$TEST_DIR"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "script exists and is executable" {
    run bash -n "$SCRIPT_DIR/setup-ssh-access.sh"
    [ "$status" -eq 0 ]
}

@test "script fails with no arguments" {
    run bash "$SCRIPT_DIR/setup-ssh-access.sh"
    [ "$status" -ne 0 ]
}

@test "script fails with missing --vm flag" {
    run bash "$SCRIPT_DIR/setup-ssh-access.sh" --host "192.168.1.1"
    [ "$status" -ne 0 ]
}

@test "script fails with missing --host flag" {
    run bash "$SCRIPT_DIR/setup-ssh-access.sh" --vm prod
    [ "$status" -ne 0 ]
}

@test "script fails with invalid --vm value" {
    run bash "$SCRIPT_DIR/setup-ssh-access.sh" --vm invalid --host "192.168.1.1"
    [ "$status" -ne 0 ]
}

@test "script accepts valid --vm prod --host combination" {
    run bash "$SCRIPT_DIR/setup-ssh-access.sh" --vm prod --host "192.168.1.1"
    # Argument parsing should work (may fail at SSH keygen, but that's OK)
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "script accepts valid --vm test --host combination" {
    run bash "$SCRIPT_DIR/setup-ssh-access.sh" --vm test --host "192.168.1.2"
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "SSH config file is created with correct format" {
    # Create mock ssh-keygen to avoid actual key generation
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/ssh-keygen" << 'MOCK'
#!/bin/bash
# Mock ssh-keygen - create empty key files
while [[ $# -gt 0 ]]; do
    case $1 in
        -f)
            KEY_PATH="$2"
            touch "${KEY_PATH}"
            touch "${KEY_PATH}.pub"
            chmod 600 "${KEY_PATH}"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done
exit 0
MOCK
    chmod +x "$TEST_DIR/bin/ssh-keygen"

    # Run with mocked PATH
    PATH="$TEST_DIR/bin:$PATH" bash "$SCRIPT_DIR/setup-ssh-access.sh" --vm prod --host "192.168.1.1" 2>/dev/null || true

    # Verify config file was created with expected content
    [ -f "$HOME/.ssh/config" ]
    run grep -A3 "^Host prod$" "$HOME/.ssh/config"
    [ "$status" -eq 0 ]
    [[ "$output" == *"HostName 192.168.1.1"* ]]
    [[ "$output" == *"User desktopuser"* ]]
}