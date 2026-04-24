"""
GitHub Actions + Terraform Hetzner Environment Data Contract

Process Flow:
1. GitHub Actions workflow triggered (workflow_dispatch)
2. Environment variables pulled from GitHub Environment (head/prod/test)
3. Environment secrets pulled from GitHub Environment
4. Terraform init with HCX S3 backend (endpoint from vars)
5. Terraform plan/apply with server name from vars
6. Deployment script runs, uses OPENCLAW_DISCORD_CHANNEL_ID from secrets
7. OpenCLAW config generated with channel from env var (no hardcoding)
"""

from pydantic import BaseModel, Field
from typing import Literal


class HetznerEnvironment(BaseModel):
    """Configuration for a Hetzner environment managed by GitHub Actions + Terraform"""

    # === GitHub Environment Variables (set in repo Settings → Environments → head/prod/test) ===
    server_name: str = Field(description="Terraform server name, must be unique in Hetzner")
    hetzner_location: str = Field(default="fsn1", description="Hetzner datacenter location")
    server_type: str = Field(default="cpx41", description="Hetzner server type")
    hetzner_ssh_key_name: str = Field(description="SSH key name registered in Hetzner")
    hcx_storage_url: str = Field(description="HCX S3 endpoint URL for Terraform state")

    # === OpenCLAW Configuration (environment-specific, via GitHub env vars) ===
    openclaw_discord_channel_id: str = Field(
        description="Discord channel ID for bindings - from GitHub env var"
    )
    openclaw_discord_allowed_user: str = Field(
        description="Discord user ID allowed to interact - from GitHub env var (format: user:XXXXXXXX)"
    )
    openclaw_discord_guild_id: str = Field(
        description="Discord guild/server ID - from GitHub env var"
    )

    # === GitHub Environment Secrets ===
    hetzner_api_token: str = Field(description="Hetzner API token for server provisioning")
    hcx_access_key: str = Field(description="HCX S3 access key for state storage")
    hcx_secret_key: str = Field(description="HCX S3 secret key for state storage")
    ssh_private_key: str = Field(description="Private key for SSH access to server")

    # === OpenCLAW Secrets (passed to deployment) ===
    discord_bot_token: str = Field(description="Discord bot token for OpenCLAW")
    openrouter_api_key: str = Field(description="OpenRouter API key for AI calls")


class WorkflowConfig(BaseModel):
    """GitHub Actions workflow configuration"""

    environment: Literal["head", "prod", "test"]
    action: Literal["plan", "apply", "destroy"] = "plan"

    terraform_version: str = "1.7"
    terraform_dir: str = "terraform"

    # Backend config (passed via -backend-config flags)
    backend_config: dict = Field(default_factory=dict)


# =============================================================================
# Environment-Specific Values (head example)
# =============================================================================
# These are set in GitHub: repo Settings → Environments → head
#
# Variables:
#   SERVER_NAME=linux-desktop-head
#   HETZNER_LOCATION=fsn1
#   SERVER_TYPE=cx23
#   HETZNER_SSH_KEY_NAME=hetzner-test
#   HCX_STORAGE_URL=https://s3.xxx.huawei.com
#   OPENCLAW_DISCORD_CHANNEL_ID=1496398999928967238
#   OPENCLAW_DISCORD_ALLOWED_USER=user:1162240440322502656
#   OPENCLAW_DISCORD_GUILD_ID=1485047825967480862
#
# Secrets:
#   HETZNER_API_TOKEN=xxx
#   HCX_ACCESS_KEY=xxx
#   HCX_SECRET_KEY=xxx
#   SSH_PRIVATE_KEY=xxx
#   DISCORD_BOT_TOKEN=xxx
#   OPENROUTER_API_KEY=xxx

# =============================================================================
# Key Principles
# =============================================================================
# 1. ALL config values from ideal-config that vary per environment MUST come from GitHub Environment variables
# 2. Config template: config/openclaw-ideal-config.json
# 3. Terraform state stored in HCX S3, not local
# 4. Existing servers imported via hcloud CLI before apply
# 5. NO hardcoded values in scripts - all from GitHub Environment settings