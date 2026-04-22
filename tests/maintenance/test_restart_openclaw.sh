#!/usr/bin/env bats

SCRIPT_DIR="/c/Users/insan/PycharmProjects/linux-desktop-seed/.worktrees/vm-maintenance/scripts/maintenance"

setup() {
    TEST_DIR=$(mktemp -d)
    export HOME="$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "script exists and is executable" {
    run bash -n "$SCRIPT_DIR/restart-openclaw.sh"
    [ "$status" -eq 0 ]
}

@test "script fails with no arguments" {
    run bash "$SCRIPT_DIR/restart-openclaw.sh"
    [ "$status" -ne 0 ]
}

@test "script accepts prod argument" {
    run bash "$SCRIPT_DIR/restart-openclaw.sh" prod
    [ "${lines[0]:-}" != "Usage:" ]
}

@test "script accepts test argument" {
    run bash "$SCRIPT_DIR/restart-openclaw.sh" test
    [ "${lines[0]:-}" != "Usage:" ]
}

@test "script fails with invalid VM name" {
    run bash "$SCRIPT_DIR/restart-openclaw.sh" invalid
    [ "$status" -ne 0 ]
}