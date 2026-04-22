#!/bin/bash
# OpenCLAW runtime configuration: config files and systemd override
# Source this from ai-tools.sh

set -euo pipefail

# Resolve lib.sh from scripts/lib/ (sibling to scripts/install/)
_lib_sh_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd -P)/scripts/deploy"
# shellcheck source=../deploy/lib.sh
source "${_lib_sh_dir}/lib.sh"

setup_openclaw_config() {
    log_step "Setting up OpenCLAW configuration..."

    local target_home
    target_home=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    local openclaw_dir="$target_home/.openclaw"
    local config_file="$openclaw_dir/openclaw.json"
    local models_file="$openclaw_dir/agents/main/agent/models.json"

    mkdir -p "$openclaw_dir/agents/main/agent"

    # Check if we need to update config (new install, force flag, or Discord token present)
    local should_update=false
    local discord_token="${DISCORD_BOT_TOKEN:-}"

    if [[ ! -f "$config_file" ]]; then
        should_update=true
    elif [[ "${FORCE_OPENCLAW_CONFIG:-false}" == "true" ]]; then
        should_update=true
    elif [[ -n "$discord_token" ]]; then
        # Check if config lacks Discord section
        if ! grep -q '"discord"' "$config_file" 2>/dev/null; then
            should_update=true
        fi
    fi

    if [[ "$should_update" == "true" ]]; then
        local repo_config="$(dirname "$SCRIPT_DIR")/config/openclaw-defaults.json"
        if [[ -f "$repo_config" ]]; then
            cp "$repo_config" "$config_file"
            log_info "Copied OpenCLAW default config"
        else
            cat > "$config_file" << 'EOF'
{
  "meta": {
    "lastTouchedVersion": "2026.04.11"
  },
  "agents": {
    "defaults": {
      "model": "openrouter/minimax/MiniMax-M2.7",
      "thinkingDefault": "minimal"
    }
  },
  "channels": {
    "discord": {
      "enabled": true,
      "token": { "source": "env", "id": "DISCORD_BOT_TOKEN" },
      "groupPolicy": "allowlist",
      "allowlist": [],
      "streaming": true
    }
  }
}
EOF
            log_info "Created minimal OpenCLAW config with Discord"
        fi
    else
        log_info "OpenCLAW config already exists"
    fi

    if [[ ! -f "$models_file" ]]; then
        local repo_models
        repo_models="$(dirname "$SCRIPT_DIR")/config/openclaw-models-sample.json"
        if [[ -f "$repo_models" ]]; then
            cp "$repo_models" "$models_file"
            log_info "Copied OpenCLAW models config"
        fi
    fi

    # Copy workspace AGENTS.md (global agent instructions)
    local repo_agents
    repo_agents="$(dirname "$SCRIPT_DIR")/config/openclaw/workspace/AGENTS.md"
    local target_agents="$openclaw_dir/workspace/AGENTS.md"
    if [[ -f "$repo_agents" && ! -f "$target_agents" ]]; then
        mkdir -p "$openclaw_dir/workspace"
        cp "$repo_agents" "$target_agents"
        log_info "Copied OpenCLAW workspace AGENTS.md"
    fi

    # Copy skills (session-commands, etc.)
    local repo_skills_dir
    repo_skills_dir="$(dirname "$SCRIPT_DIR")/config/openclaw/skills"
    local target_skills_dir="$openclaw_dir/skills"
    if [[ -d "$repo_skills_dir" ]]; then
        mkdir -p "$target_skills_dir"
        cp -r "$repo_skills_dir"/* "$target_skills_dir/" 2>/dev/null || true
        log_info "Copied OpenCLAW skills"
    fi

    chown -R "$TARGET_USER:$TARGET_USER" "$openclaw_dir"
    log_info "OpenCLAW configuration complete for user $TARGET_USER"
}

setup_openclaw_systemd_override() {
    log_step "Setting up OpenCLAW systemd override for API key persistence..."

    local target_home
    target_home=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    local override_dir="$target_home/.config/systemd/user/openclaw-gateway.service.d"
    local override_file="$override_dir/override.conf"

    local api_key="${OPENROUTER_API_KEY:-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}"
    local discord_token="${DISCORD_BOT_TOKEN:-}"

    mkdir -p "$override_dir"

    # Build environment file with available tokens
    local env_vars="Environment=OPENROUTER_API_KEY=$api_key"
    if [[ -n "$discord_token" ]]; then
        env_vars="$env_vars\nEnvironment=DISCORD_BOT_TOKEN=$discord_token"
    fi

    cat > "$override_file" << EOF
[Service]
Environment=OPENROUTER_API_KEY=$api_key
Environment=HOME=/root
Environment=XDG_RUNTIME_DIR=/run/user/0
EOF

    # Append Discord token if available
    if [[ -n "$discord_token" ]]; then
        echo "Environment=DISCORD_BOT_TOKEN=$discord_token" >> "$override_file"
    fi

    chown -R "$TARGET_USER:$TARGET_USER" "$target_home/.config"
    log_info "OpenCLAW systemd override created at $override_file"
}

export -f setup_openclaw_config setup_openclaw_systemd_override