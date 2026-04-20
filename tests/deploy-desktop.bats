#!/usr/bin/env bats
# BATS tests for linux-desktop-seed deployment script

# Get the project root directory
PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# Test syntax validation
@test "deploy-desktop.sh syntax is valid" {
    run bash -n "$PROJECT_ROOT/deploy-desktop.sh"
    [ "$status" -eq 0 ]
}

@test "config.sh syntax is valid" {
    run bash -n "$PROJECT_ROOT/config.sh"
    [ "$status" -eq 0 ]
}

@test "validate-install.sh syntax is valid" {
    run bash -n "$BATS_TEST_DIRNAME/validate-install.sh"
    [ "$status" -eq 0 ]
}

# Test config.sh functions exist
@test "config.sh has get_component_keys function" {
    source "$PROJECT_ROOT/config.sh"
    declare -f get_component_keys > /dev/null
    [ $? -eq 0 ]
}

@test "config.sh has verify_component function" {
    source "$PROJECT_ROOT/config.sh"
    declare -f verify_component > /dev/null
    [ $? -eq 0 ]
}

@test "config.sh has verify_all_components function" {
    source "$PROJECT_ROOT/config.sh"
    declare -f verify_all_components > /dev/null
    [ $? -eq 0 ]
}

# Test component keys are extracted correctly
@test "config.sh declares expected components" {
    source "$PROJECT_ROOT/config.sh"
    local keys
    keys=$(get_component_keys)

    # Should have multiple components
    echo "$keys" | grep -q "gnome"
    echo "$keys" | grep -q "xrdp"
    echo "$keys" | grep -q "vscode"
}

# Test component definitions have required fields
@test "components have name, check, and required fields" {
    source "$PROJECT_ROOT/config.sh"

    # GNOME Desktop
    [ -n "${COMPONENTS[gnome_name]}" ]
    [ -n "${COMPONENTS[gnome_check]}" ]
    [ -n "${COMPONENTS[gnome_required]}" ]

    # xrdp
    [ -n "${COMPONENTS[xrdp_name]}" ]
    [ -n "${COMPONENTS[xrdp_check]}" ]
    [ -n "${COMPONENTS[xrdp_required]}" ]

    # VS Code
    [ -n "${COMPONENTS[vscode_name]}" ]
    [ -n "${COMPONENTS[vscode_check]}" ]
    [ -n "${COMPONENTS[vscode_required]}" ]
}

# Test validate-install.sh sources config.sh
@test "validate-install.sh sources config.sh" {
    run bash -c "source $BATS_TEST_DIRNAME/validate-install.sh 2>&1"
    # Should not have errors about missing config.sh
    echo "$output" | grep -qv "config.sh: not found"
}