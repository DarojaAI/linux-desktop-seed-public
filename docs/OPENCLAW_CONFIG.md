# OpenCLAW Configuration Files

**OpenCLAW Version:** v2026.04.11 (MiniMax compatible)

This directory contains the configuration templates and samples for OpenCLAW deployment.

## Files

### `config/openclaw-defaults.json`
Main configuration template. Deployed to `/home/desktopuser/.openclaw/openclaw.json` during VM setup.

**Key settings:**
- Model: `openrouter/minimax/MiniMax-M2.7`
- `thinkingDefault: "minimal"` - Required for MiniMax compatibility
- Discord bot enabled with allowlist
- Gateway on port 18789 with token auth

### `config/openclaw-models-sample.json`
Agent models configuration. Deployed to `/home/desktopuser/.openclaw/agents/main/agent/models.json`.

**Key fields:**
- `reasoning: true` - Enables thinking tokens (required for MiniMax, Hunter, Healer)
- `contextWindow` - Max input tokens
- `maxTokens` - Max output tokens
- `cost` - Pricing for rate limiting

### `config/openclaw-ideal-config.json`
Reference configuration template (not deployed). Contains placeholders for tokens that must be replaced at deploy time:

- `DISCORD_BOT_TOKEN_PLACEHOLDER` - Replace with actual Discord bot token
- `GATEWAY_AUTH_TOKEN_PLACEHOLDER` - Replace with gateway auth token

This file is excluded from version control via `.gitignore`.

## Deployment

The deployment script (`deploy-desktop.sh`) handles:

1. **Version pinning**: OpenCLAW pinned to `2026.04.11` (MiniMax compatible)
2. **Config merge**: Copies defaults, preserves existing channels
3. **Models setup**: Copies `models.json` with reasoning-enabled models
4. **Auth**: Reads API keys from environment variables

## Environment Variables

Required for deployment:
- `OPENROUTER_API_KEY` - OpenRouter API key
- `DISCORD_BOT_TOKEN` - Discord bot token
- `DISCORD_ALLOWLIST_IDS` - Comma-separated user IDs allowed to use the bot