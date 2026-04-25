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
    local discord_channel_id="${OPENCLAW_DISCORD_CHANNEL_ID:-}"
    local discord_allowed_user="${OPENCLAW_DISCORD_ALLOWED_USER:-}"
    local discord_guild_id="${OPENCLAW_DISCORD_GUILD_ID:-}"

    mkdir -p "$openclaw_dir/agents/main/agent"

    # Check if we need to update config (new install, force flag, or guilds missing)
    local should_update=false

    if [[ ! -f "$config_file" ]]; then
        should_update=true
    elif [[ "${FORCE_OPENCLAW_CONFIG:-false}" == "true" ]]; then
        should_update=true
    fi

    # Always update if channel ID is provided but config lacks guilds structure
    if [[ -n "$discord_channel_id" && -f "$config_file" ]]; then
        if ! grep -q '"guilds"' "$config_file" 2>/dev/null; then
            should_update=true
            log_info "Config outdated - missing guilds structure, will update"
        fi
    fi

    # Update if config has plain tokens (not using ${VAR} env substitution)
    if [[ -f "$config_file" ]]; then
        if grep -qE '^[[:space:]]*"token":[[:space:]]*"[A-Z0-9]' "$config_file" 2>/dev/null && \
           ! grep -qE '^[[:space:]]*"token":[[:space:]]*"\${' "$config_file" 2>/dev/null; then
            should_update=true
            log_info "Config uses plain tokens, will update to use env substitution"
        fi
    fi

    if [[ "$should_update" == "true" ]]; then
        local repo_config="$(dirname "$SCRIPT_DIR")/../../config/openclaw-defaults.json"
        if [[ -f "$repo_config" ]]; then
            # Copy default config (tokens are now env references)
            cp "$repo_config" "$config_file"
            log_info "Copied OpenCLAW default config with env-based token resolution"
        else
            # Create minimal config with env references
            cat > "$config_file" << 'EOF'
{
  "meta": {
    "lastTouchedVersion": "2026.04.11"
  },
  "auth": {
    "profiles": {
      "openrouter:default": {
        "provider": "openrouter",
        "mode": "api_key"
      }
    }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "openrouter": {
        "baseUrl": "https://openrouter.ai/api/v1",
        "apiKey": { "source": "env", "id": "OPENROUTER_API_KEY" },
        "api": "openai-completions",
        "models": [
          { "id": "minimax/MiniMax-M2.7", "name": "MiniMax-M2.7", "api": "openai-completions" }
        ]
      }
    }
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
      "token": "${DISCORD_BOT_TOKEN}",
      "groupPolicy": "allowlist",
      "streaming": { "mode": "off" },
      "allowFrom": [],
      "guilds": {}
    }
  },
  "gateway": {
    "mode": "local"
  }
}
EOF
            log_info "Created minimal OpenCLAW config with env-based token resolution"
        fi
    else
        log_info "OpenCLAW config already exists"
    fi
  "channels": {
    "discord": {
      "enabled": true,
      "token": "$token_value",
      "groupPolicy": "allowlist",
      "streaming": { "mode": "off" },
      "allowFrom": [],
      "guilds": {}
    }
  },
  "gateway": {
    "mode": "local"
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

    # API key must come from environment variable
    local api_key="${OPENROUTER_API_KEY:-}"
    if [[ -z "$api_key" ]]; then
        log_error "OPENROUTER_API_KEY environment variable is required"
        return 1
    fi
    local discord_token="${DISCORD_BOT_TOKEN:-}"

    # Get user ID for XDG_RUNTIME_DIR
    local user_id
    user_id=$(id -u "$TARGET_USER")

    mkdir -p "$override_dir"

    cat > "$override_file" << EOF
[Service]
Environment=OPENROUTER_API_KEY=$api_key
Environment=HOME=$target_home
Environment=XDG_RUNTIME_DIR=/run/user/$user_id
EOF

    # Add ANTHROPIC_API_BASE if provided (optional, for OpenRouter proxy)
    local anthropic_base="${ANTHROPIC_API_BASE:-}"
    if [[ -n "$anthropic_base" ]]; then
        echo "Environment=ANTHROPIC_API_BASE=$anthropic_base" >> "$override_file"
    fi

    # Append Discord token if available
    if [[ -n "$discord_token" ]]; then
        echo "Environment=DISCORD_BOT_TOKEN=$discord_token" >> "$override_file"
    fi

    chown -R "$TARGET_USER:$TARGET_USER" "$target_home/.config"
    log_info "OpenCLAW systemd override created at $override_file"
}

setup_openclaw_agent_binding() {
    log_step "Setting up OpenCLAW default agent (linux-desktop-seed)..."

    local target_home
    target_home=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    local openclaw_dir="$target_home/.openclaw"
    local config_file="$openclaw_dir/openclaw.json"
    local projects_dir="$target_home/GithubProjects"

    # Channel ID must be provided via GitHub Actions
    local discord_channel_id="${OPENCLAW_DISCORD_CHANNEL_ID:-}"
    local discord_allowed_user="${OPENCLAW_DISCORD_ALLOWED_USER:-}"
    local discord_guild_id="${OPENCLAW_DISCORD_GUILD_ID:-}"
    if [[ -z "$discord_channel_id" ]]; then
        log_warn "OPENCLAW_DISCORD_CHANNEL_ID not set, skipping agent binding"
        return 0
    fi

    # Fixed repo name for default agent
    local repo_name="linux-desktop-seed"
    local repo_dir="$projects_dir/$repo_name"

    # Clone the repo if it doesn't exist
    if [[ ! -d "$repo_dir" ]]; then
        log_info "Cloning linux-desktop-seed repo..."

        # Get repo URL from current deployment
        local repo_url="${REPO_URL:-}"
        if [[ -z "$repo_url" ]]; then
            if [[ -d "$SCRIPT_DIR/.git" ]]; then
                repo_url=$(cd "$SCRIPT_DIR" && git remote get-url origin 2>/dev/null) || true
            fi
        fi

        if [[ -n "$repo_url" ]]; then
            mkdir -p "$projects_dir"
            if git clone "$repo_url" "$repo_dir" 2>/dev/null; then
                log_info "Repo cloned to $repo_dir"
                chown -R "$TARGET_USER:$TARGET_USER" "$projects_dir"
            else
                log_warn "Could not clone repo"
            fi
        fi
    else
        log_info "Repo already exists at $repo_dir"
    fi

    # Ensure git remote is set to correct GitHub URL
    if [[ -d "$repo_dir/.git" ]]; then
        cd "$repo_dir"
        if ! git remote get-url origin &>/dev/null; then
            log_info "Adding git remote origin..."
            git remote add origin https://github.com/DarojaAI/linux-desktop-seed.git
        else
            current_remote=$(git remote get-url origin)
            if [[ "$current_remote" != "https://github.com/DarojaAI/linux-desktop-seed.git" ]]; then
                log_info "Updating git remote to correct URL..."
                git remote set-url origin https://github.com/DarojaAI/linux-desktop-seed.git
            fi
        fi
        # Pull latest changes
        log_info "Pulling latest changes..."
        git fetch origin || true
        git pull origin master 2>/dev/null || git pull origin main 2>/dev/null || true
    fi

    # Check if config exists
    if [[ ! -f "$config_file" ]]; then
        log_warn "OpenCLAW config not found, run setup_openclaw_config first"
        return 0
    fi

    # Use Python to add agent and binding - pass bash vars as env vars to avoid interpolation issues
    discord_channel_id="$discord_channel_id" \
    discord_allowed_user="$discord_allowed_user" \
    discord_guild_id="$discord_guild_id" \
    repo_name="$repo_name" \
    repo_dir="$repo_dir" \
    openclaw_dir="$openclaw_dir" \
    python3 -c "
import json
import os

config_file = '$config_file'
repo_name = os.environ.get('repo_name', 'linux-desktop-seed')
repo_dir = os.environ.get('repo_dir', '')
openclaw_dir = os.environ.get('openclaw_dir', '')
discord_channel_id = os.environ.get('discord_channel_id', '')
discord_allowed_user = os.environ.get('discord_allowed_user', '')
discord_guild_id = os.environ.get('discord_guild_id', '')

if not discord_channel_id:
    print('No discord_channel_id provided, skipping binding')
    exit(0)

with open(config_file, 'r') as f:
    config = json.load(f)

# Ensure agents list exists
if 'agents' not in config:
    config['agents'] = {'list': []}
if 'list' not in config['agents']:
    config['agents']['list'] = []

# Add linux-desktop-seed agent if not exists
agent_exists = any(a.get('id') == repo_name for a in config['agents']['list'])
if not agent_exists:
    agent = {
        'id': repo_name,
        'name': repo_name,
        'model': 'openrouter/minimax/MiniMax-M2.7',
        'workspace': repo_dir,
        'agentDir': f'{openclaw_dir}/agents/{repo_name}/agent'
    }
    config['agents']['list'].append(agent)
    print(f'Added agent: {repo_name}')

# Ensure bindings list exists
if 'bindings' not in config:
    config['bindings'] = []

# Add binding if not exists
binding_exists = any(b.get('agentId') == repo_name for b in config['bindings'])
if not binding_exists:
    binding = {
        'type': 'route',
        'agentId': repo_name,
        'match': {
            'channel': 'discord',
            'peer': {'kind': 'channel', 'id': discord_channel_id}
        }
    }
    config['bindings'].append(binding)
    print(f'Added binding: {repo_name} -> {discord_channel_id}')

# Add channel to allowed list
if 'channels' in config and 'discord' in config.get('channels', {}):
    discord_config = config['channels']['discord']
    guild_id = discord_guild_id if discord_guild_id else ''
    if not guild_id:
        print('ERROR: OPENCLAW_DISCORD_GUILD_ID not set')
        sys.exit(1)
    if 'guilds' not in discord_config:
        discord_config['guilds'] = {}
    if guild_id not in discord_config['guilds']:
        discord_config['guilds'][guild_id] = {'channels': {}}
    if 'channels' not in discord_config['guilds'][guild_id]:
        discord_config['guilds'][guild_id]['channels'] = {}
    discord_config['guilds'][guild_id]['channels'][discord_channel_id] = {}

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
print('Config updated')
" || log_warn "Failed to update config"

    chown -R "$TARGET_USER:$TARGET_USER" "$openclaw_dir"
    log_info "OpenCLAW agent binding complete"
}

export -f setup_openclaw_config setup_openclaw_systemd_override setup_openclaw_agent_binding