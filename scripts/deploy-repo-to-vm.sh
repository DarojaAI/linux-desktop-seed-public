#!/bin/bash
# Deploy GitHub repository to VM and notify Discord
# Usage: ./deploy-repo-to-vm.sh <repo> [branch]
# Example: ./deploy-repo-to-vm.sh patelmm79/dev-nexus-action-agent main

set -euo pipefail

REPO="${1:-}"
BRANCH="${2:-main}"
DISCORD_CHANNEL_ID="${DISCORD_CHANNEL_ID:-}"

# Logging
log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

# Validate input
if [[ -z "$REPO" ]]; then
    log_error "Usage: $0 <repo> [branch]"
    exit 1
fi

# Parse owner/repo from various formats
parse_repo() {
    local input="$1"
    # Remove .git suffix if present
    input="${input%.git}"
    # Extract owner/repo from URLs or plain format
    if [[ "$input" =~ github\.com[:/]([^/]+/[^/]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$input" =~ ^([^/]+/[^/]+)$ ]]; then
        echo "$input"
    else
        echo ""
    fi
}

# Send Discord notification via OpenCLAW or direct API
send_discord() {
    local message="$1"
    local channel_id="${DISCORD_CHANNEL_ID:-}"

    # If no channel provided, try to get it from repo name
    if [[ -z "$channel_id" ]]; then
        # Use repo name as channel name (e.g., "intelligent-feed")
        local channel_name
        channel_name=$(echo "$REPO" | cut -d'/' -f2 | tr '[:upper:]' '[:lower:]')
        channel_id=$(get_channel_id_by_name "$channel_name")
    fi

    # If channel lookup failed, fail explicitly - don't guess
    if [[ -z "$channel_id" ]]; then
        log_error "Could not find Discord channel for repo '$REPO'. Please provide DISCORD_CHANNEL_ID explicitly."
        return 1
    fi

    # Try OpenCLAW first
    if command -v openclaw &> /dev/null; then
        if openclaw message send --channel discord --target "$channel_id" --message "$message" 2>&1; then
            log_info "Discord notification sent via OpenCLAW"
            return 0
        fi
    fi

    # Fall back to direct Discord API
    local discord_token
    discord_token=$(jq -r '.channels.discord.token' ~/.openclaw/openclaw.json 2>/dev/null || true)

    if [[ -n "$discord_token" ]]; then
        if curl -s -X POST "https://discord.com/api/v10/channels/$channel_id/messages" \
            -H "Authorization: Bot $discord_token" \
            -H "Content-Type: application/json" \
            -d "{\"content\": \"$message\"}" > /dev/null 2>&1; then
            log_info "Discord notification sent via API"
            return 0
        fi
    fi

    log_warn "Failed to send Discord notification"
    log_info "Message: $message"
}

# Look up channel ID by name via Discord API (case-insensitive)
get_channel_id_by_name() {
    local channel_name="$1"
    local discord_token guild_id

    discord_token=$(jq -r '.channels.discord.token' ~/.openclaw/openclaw.json 2>/dev/null || true)
    guild_id=$(jq -r '.channels.discord.guilds | keys[0]' ~/.openclaw/openclaw.json 2>/dev/null || true)

    if [[ -z "$discord_token" || -z "$guild_id" ]]; then
        echo ""
        return
    fi

    # Lowercase the search term in bash
    local channel_name_lower
    channel_name_lower=$(echo "$channel_name" | tr '[:upper:]' '[:lower:]')

    # Get channels and find matching ID using process substitution
    while IFS='|' read -r id name; do
        name_lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')
        if [[ "$name_lower" == "$channel_name_lower" ]]; then
            echo "$id"
            return 0
        fi
    done < <(curl -s "https://discord.com/api/v10/guilds/$guild_id/channels" \
        -H "Authorization: Bot $discord_token" | jq -r '.[] | .id + "|" + .name' 2>/dev/null) || true
}

# Main deployment logic
main() {
    local owner repo

    # Notification settings: set SKIP_NOTIFICATIONS=true to disable
    : "${SKIP_NOTIFICATIONS:=false}"

    # Parse and validate repo
    local parsed
    parsed=$(parse_repo "$REPO")
    if [[ -z "$parsed" ]]; then
        log_error "Invalid repository format: $REPO"
        if [[ "${SKIP_NOTIFICATIONS:-false}" != "true" ]]; then
            send_discord "❌ Invalid repository format: $REPO. Use owner/repo or full GitHub URL"
        fi
        exit 1
    fi

    owner=$(echo "$parsed" | cut -d'/' -f1)
    repo=$(echo "$parsed" | cut -d'/' -f2)

    # Validate branch name to prevent shell injection
    if [[ ! "$BRANCH" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        log_error "Invalid branch name: $BRANCH"
        exit 1
    fi

    # Determine target directory - use desktopuser's home if root (OpenCLAW runs as desktopuser)
    local target_user_home
    if [[ "$(id -u)" == "0" ]] && id desktopuser &>/dev/null; then
        target_user_home="/home/desktopuser"
    else
        target_user_home="$HOME"
    fi
    local target_dir="$target_user_home/repos/$owner/$repo"

    # Check if already exists (idempotency)
    if [[ -d "$target_dir" ]]; then
        local message="ℹ️ Repository already deployed: $owner/$repo\nLocation: $target_dir"
        log_info "$message"
        if [[ "${SKIP_NOTIFICATIONS:-false}" != "true" ]]; then
            send_discord "ℹ️ Repository already deployed: $owner/$repo - Location: $target_dir"
        fi
        exit 0
    fi

    # Create parent directory
    mkdir -p "$HOME/repos/$owner"

    # Clone repository
    log_info "Cloning $owner/$repo (branch: $BRANCH) to $target_dir..."
    if git clone --depth 1 -b "$BRANCH" "https://github.com/$owner/$repo.git" "$target_dir" 2>&1; then
        local message="✅ Repository deployed to VM: $owner/$repo ($BRANCH)\nLocation: $target_dir"
        log_info "$message"
        if [[ "${SKIP_NOTIFICATIONS:-false}" != "true" ]]; then
            send_discord "✅ Repository deployed to VM: $owner/$repo ($BRANCH) - Location: $target_dir"
        fi
    else
        local message="❌ Failed to deploy $owner/$repo: Clone failed"
        log_error "$message"
        if [[ "${SKIP_NOTIFICATIONS:-false}" != "true" ]]; then
            send_discord "❌ Failed to deploy $owner/$repo: Clone failed"
        fi
        exit 1
    fi
}

main "$@"
