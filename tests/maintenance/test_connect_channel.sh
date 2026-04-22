#!/usr/bin/env bats

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../scripts/maintenance" && pwd)"

setup() {
    TEST_DIR=$(mktemp -d)
    export HOME="$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "script exists and is executable" {
    run bash -n "$SCRIPT_DIR/connect-channel.sh"
    [ "$status" -eq 0 ]
}

@test "script fails with no arguments" {
    run bash "$SCRIPT_DIR/connect-channel.sh"
    [ "$status" -ne 0 ]
}

@test "script fails with missing --channel" {
    run bash "$SCRIPT_DIR/connect-channel.sh" --agent "my-agent" --vm prod
    [ "$status" -ne 0 ]
}

@test "script fails with missing --agent" {
    run bash "$SCRIPT_DIR/connect-channel.sh" --channel "my-channel" --vm prod
    [ "$status" -ne 0 ]
}

@test "script fails with missing --vm" {
    run bash "$SCRIPT_DIR/connect-channel.sh" --channel "my-channel" --agent "my-agent"
    [ "$status" -ne 0 ]
}

@test "script accepts valid arguments" {
    run bash "$SCRIPT_DIR/connect-channel.sh" --channel "my-channel" --agent "my-agent" --vm prod
    [ "${lines[0]:-}" != "Usage:" ]
}

@test "script rejects invalid VM name" {
    run bash "$SCRIPT_DIR/connect-channel.sh" --channel "my-channel" --agent "my-agent" --vm invalid
    [ "$status" -ne 0 ]
}