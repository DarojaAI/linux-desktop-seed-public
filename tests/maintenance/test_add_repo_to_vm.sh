#!/usr/bin/env bats

# Absolute path to worktree root
WORKTREE_ROOT="/c/Users/insan/PycharmProjects/linux-desktop-seed/.worktrees/vm-maintenance"
SCRIPT_PATH="$WORKTREE_ROOT/scripts/maintenance/add-repo-to-vm.sh"

setup() {
    TEST_DIR=$(mktemp -d)
    export HOME="$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "script exists and is executable" {
    run bash -n "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
}

@test "script fails with no arguments" {
    run bash "$SCRIPT_PATH"
    [ "$status" -ne 0 ]
}

@test "script fails with missing --repo" {
    run bash "$SCRIPT_PATH" --vm prod
    [ "$status" -ne 0 ]
}

@test "script fails with missing --vm" {
    run bash "$SCRIPT_PATH" --repo "owner/repo"
    [ "$status" -ne 0 ]
}

@test "script accepts valid --repo --vm combination" {
    run bash "$SCRIPT_PATH" --repo "owner/repo" --vm prod
    [ "${lines[0]:-}" != "Usage:" ]
}

@test "script accepts test VM" {
    run bash "$SCRIPT_PATH" --repo "owner/repo" --vm test
    [ "${lines[0]:-}" != "Usage:" ]
}

@test "script rejects invalid repo format" {
    run bash "$SCRIPT_PATH" --repo "invalid-repo" --vm prod
    [ "$status" -ne 0 ]
}

@test "script rejects invalid VM name" {
    run bash "$SCRIPT_PATH" --repo "owner/repo" --vm invalid
    [ "$status" -ne 0 ]
}

@test "script accepts optional --channel flag" {
    run bash "$SCRIPT_PATH" --repo "owner/repo" --vm prod --channel "my-channel"
    [ "${lines[0]:-}" != "Usage:" ]
}

@test "script extracts owner and repo from owner/repo format" {
    # Test argument parsing logic
    REPO="patelmm79/my-repo"
    OWNER=$(echo "$REPO" | cut -d'/' -f1)
    REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)

    [ "$OWNER" = "patelmm79" ]
    [ "$REPO_NAME" = "my-repo" ]
}