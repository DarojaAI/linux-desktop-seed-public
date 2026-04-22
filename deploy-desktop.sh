#!/bin/bash
set -euo pipefail

# Remote Linux Desktop Deployment Script - Modular Version
# Deploys: GNOME, xrdp, VS Code, Claude Code, Chromium, OpenRouter
# Target: Ubuntu 20.04/22.04/24.04

SCRIPT_VERSION="2.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LOG_FILE="/tmp/deploy-desktop-$(date +%Y%m%d-%H%M%S).log"
TARGET_USER="desktopuser"

# Dry run mode - preview what would be installed without actually installing
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run|--preview)
            DRY_RUN=true
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run, --preview  Show what would be installed without installing"
            echo "  --help, -h            Show this help message"
            echo ""
            exit 0
            ;;
    esac
done

# Source all modules
source "$SCRIPT_DIR/scripts/deploy/lib.sh"
source "$SCRIPT_DIR/scripts/deploy/system.sh"
source "$SCRIPT_DIR/scripts/deploy/dev-tools.sh"
source "$SCRIPT_DIR/scripts/deploy/ai-tools.sh"
source "$SCRIPT_DIR/scripts/deploy/desktop-environment.sh"
source "$SCRIPT_DIR/scripts/deploy/configure.sh"

# Main function
main() {
    # Handle dry-run mode
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "========================================="
        echo "  DRY RUN MODE - No changes will be made"
        echo "========================================="
        echo ""
        log_info "This would install the following components:"
        log_info "  - GNOME Desktop"
        log_info "  - xrdp (RDP server)"
        log_info "  - Visual Studio Code"
        log_info "  - Claude Code"
        log_info "  - OpenRouter CLI"
        log_info "  - Claude Code Router"
        log_info "  - Chromium Browser"
        log_info "  - GitHub CLI"
        log_info "  - Bun runtime"
        log_info "  - OpenCLAW"
        log_info "  - Terraform & Terragrunt"
        log_info "  - Google Cloud SDK"
        log_info "  - Session monitoring"
        log_info "  - GNOME extensions"
        log_info "  - VM maintenance scripts"
        echo ""
        log_info "To run this deployment:"
        log_info "  sudo bash deploy-desktop.sh"
        echo ""
        exit 0
    fi

    # Opt-out flags: set SKIP_<GROUP>=true to disable a category
    # e.g. sudo SKIP_AI_TOOLS=true bash deploy-desktop.sh
    : "${SKIP_SYSTEM:=false}"  "${SKIP_DEV_TOOLS:=false}"  "${SKIP_AI_TOOLS:=false}"
    : "${SKIP_CONFIG:=false}"  "${SKIP_MONITORING:=false}"  "${SKIP_OPTIONAL:=false}"

    log_info "Starting Remote Desktop Deployment v$SCRIPT_VERSION"
    log_info "Log file: $LOG_FILE"

    check_root
    detect_ubuntu_version

    # System setup
    if [[ "${SKIP_SYSTEM:-false}" != "true" ]]; then
        update_system
        install_gnome
        configure_xwrapper
        install_xrdp
        create_desktop_user
        copy_desktop_configs
    fi

    # Development tools
    if [[ "${SKIP_DEV_TOOLS:-false}" != "true" ]]; then
        install_vscode
        install_claude_code
        install_claude_skills
        configure_claude_openrouter
        install_openrouter
        install_claude_code_router
        install_chromium
        install_ghcli
        install_bun
        install_terraform
        install_gcloud
    fi

    # AI tools (OpenCLAW, OpenRouter)
    if [[ "${SKIP_AI_TOOLS:-false}" != "true" ]]; then
        install_openclaw
        setup_openclaw_wrapper
        setup_openclaw_config
        setup_openclaw_lock_config
        setup_openclaw_validate_config
        setup_openclaw_backup_config
        setup_openclaw_change_request
        setup_openclaw_systemd_override
        setup_openclaw_systemd_service
    fi

    # Configuration
    if [[ "${SKIP_CONFIG:-false}" != "true" ]]; then
        setup_environment
        configure_mcp_servers
        create_desktop_shortcuts
    fi

    # Monitoring & reliability
    if [[ "${SKIP_MONITORING:-false}" != "true" ]]; then
        setup_keyring
        setup_monitoring
        setup_gnome_extensions
    fi

    # Optional features
    if [[ "${SKIP_OPTIONAL:-false}" != "true" ]]; then
        setup_token_rotation_cron
        setup_github_issues
    fi

    # VM Maintenance Scripts (for head VM controlling other VMs)
    install_maintenance_scripts

    # Validation
    validate_deployment
    show_summary

    log_info "System ready for deployment"
}

# Install maintenance scripts for VM-A head node
install_maintenance_scripts() {
    log_info "Installing VM maintenance scripts..."

    local scripts_dir="$SCRIPT_DIR/scripts/maintenance"
    local target_dir="/home/$TARGET_USER/maintenance-scripts"

    if [[ ! -d "$scripts_dir" ]]; then
        log_warn "Maintenance scripts directory not found: $scripts_dir"
        return 0
    fi

    # Create target directory
    mkdir -p "$target_dir"

    # Copy all maintenance scripts
    for script in "$scripts_dir"/*.sh; do
        if [[ -f "$script" ]]; then
            cp "$script" "$target_dir/"
            chmod +x "$target_dir/$(basename "$script")"
            log_info "  Installed: $(basename "$script")"
        fi
    done

    # Set ownership
    chown -R "$TARGET_USER:$TARGET_USER" "$target_dir"

    log_info "Maintenance scripts installed to $target_dir"
}

main "$@"
