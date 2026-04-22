#!/bin/bash
# scripts/maintenance/add-repo-to-vm.sh
# Add a GitHub repo to target VM with 1:1:1 OpenCLAW setup

set -euo pipefail

# Parse arguments
REPO=""
TARGET_VM=""
CHANNEL_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --repo)
            REPO="$2"
            shift 2
            ;;
        --vm)
            TARGET_VM="$2"
            shift 2
            ;;
        --channel)
            CHANNEL_NAME="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$REPO" || -z "$TARGET_VM" ]]; then
    echo "Usage: $0 --repo <owner/repo> --vm <prod|test> [--channel <discord-channel>]"
    exit 1
fi

# Extract owner and repo name
OWNER=$(echo "$REPO" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)

if [[ -z "$OWNER" || -z "$REPO_NAME" ]]; then
    echo "Error: Repo must be in format owner/repo (e.g., patelmm79/my-repo)"
    exit 1
fi

# Validate VM
if [[ "$TARGET_VM" != "prod" && "$TARGET_VM" != "test" ]]; then
    echo "Error: VM must be 'prod' or 'test'"
    exit 1
fi

# Use repo name as channel if not specified
if [[ -z "$CHANNEL_NAME" ]]; then
    CHANNEL_NAME="$REPO_NAME"
fi

echo "=== Adding repo $REPO to $TARGET_VM ==="
echo "Channel: $CHANNEL_NAME"
echo ""

# Execute on target VM
ssh "$TARGET_VM" << EOF
set -euo pipefail

PROJECTS_DIR="\$HOME/Projects"
AGENT_ID="$REPO_NAME"
AGENT_DIR="\$HOME/.openclaw/agents/\${AGENT_ID}"
REPO_URL="https://github.com/$REPO.git"

echo "--- Step 1: Clone Repository ---"
mkdir -p "\$PROJECTS_DIR"
cd "\$PROJECTS_DIR"

if [[ -d "\$REPO_NAME" ]]; then
    echo "Repository \$REPO_NAME already exists"
    cd "\$REPO_NAME"
    git pull origin \$(git branch --show-current)
else
    git clone "\$REPO_URL" "\$REPO_NAME"
    cd "\$REPO_NAME"
fi

git config --global --add safe.directory "\$PROJECTS_DIR/\$REPO_NAME"
echo "✓ Repository cloned/updated"
echo ""

echo "--- Step 2: Create Agent Directory Structure ---"
mkdir -p "\${AGENT_DIR}/agent/memory"
mkdir -p "\${AGENT_DIR}/agent/sessions"
mkdir -p "\${AGENT_DIR}/mcp-servers"
echo "✓ Directory structure created"
echo ""

echo "--- Step 3: Copy models.json ---"
cp "\$HOME/.openclaw/agents/main/agent/models.json" \
   "\${AGENT_DIR}/agent/models.json" || true
echo "✓ models.json copied"
echo ""

echo "--- Step 4: Create agent config.json ---"
cat > "\${AGENT_DIR}/agent/config.json" << 'AGENT_EOF'
{
  "defaults": {
    "model": "minimax/MiniMax-M2.7",
    "thinkingDefault": "minimal",
    "compaction": {
      "mode": "safeguard",
      "reserveTokens": 15000,
      "keepRecentTokens": 4000,
      "reserveTokensFloor": 20000,
      "maxHistoryShare": 0.1,
      "model": "anthropic/claude-haiku-4-5"
    }
  },
  "workspace": {
    "path": "REPLACE_WITH_PROJECT_PATH",
    "repoUrl": "REPLACE_WITH_REPO_URL"
  }
}
AGENT_EOF

# Replace placeholders
sed -i "s|REPLACE_WITH_PROJECT_PATH|\$PROJECTS_DIR/\$REPO_NAME|g" "\${AGENT_DIR}/agent/config.json"
sed -i "s|REPLACE_WITH_REPO_URL|\$REPO_URL|g" "\${AGENT_DIR}/agent/config.json"
echo "✓ config.json created"
echo ""

echo "--- Step 5: Copy auth-profiles.json ---"
cp "\$HOME/.openclaw/agents/main/agent/auth-profiles.json" \
   "\${AGENT_DIR}/agent/auth-profiles.json" 2>/dev/null || true
echo "✓ auth-profiles.json copied"
echo ""

echo "--- Step 6: Set Permissions ---"
chown -R desktopuser:desktopuser "\${AGENT_DIR}"
chmod -R 700 "\${AGENT_DIR}/agent/memory"
echo "✓ Permissions set"
echo ""

echo "--- Step 7: Restart OpenCLAW Gateway ---"
pkill -f 'openclaw gateway' || true
sleep 2
cd "\$HOME"
nohup openclaw gateway > /tmp/openclaw-gateway.log 2>&1 &
sleep 3

if pgrep -f 'openclaw gateway' > /dev/null; then
    echo "✓ OpenCLAW gateway restarted"
else
    echo "✗ Warning: Gateway may not have started correctly"
fi
echo ""

echo "=== Setup Complete ==="
echo "Repo:       \$REPO_URL"
echo "Local:      \$PROJECTS_DIR/\$REPO_NAME"
echo "Agent:      \$AGENT_ID"
echo "Channel:    #$CHANNEL_NAME (you need to create this and map it manually)"
EOF

echo ""
echo "Done! Repository $REPO has been added to $TARGET_VM"
echo "Next steps:"
echo "  1. Create Discord channel #$CHANNEL_NAME"
echo "  2. Get the channel ID"
echo "  3. Run: ./connect-channel.sh --vm $TARGET_VM --channel $CHANNEL_NAME --agent $REPO_NAME"