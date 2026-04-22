#!/bin/bash
# scripts/maintenance/connect-channel.sh
# Map a Discord channel to an OpenCLAW agent on target VM

set -euo pipefail

# Parse arguments
CHANNEL_NAME=""
AGENT_ID=""
TARGET_VM=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --channel)
            CHANNEL_NAME="$2"
            shift 2
            ;;
        --agent)
            AGENT_ID="$2"
            shift 2
            ;;
        --vm)
            TARGET_VM="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$CHANNEL_NAME" || -z "$AGENT_ID" || -z "$TARGET_VM" ]]; then
    echo "Usage: $0 --channel <discord-channel> --agent <agent-id> --vm <prod|test>"
    echo "Example: $0 --channel my-repo --agent my-repo --vm prod"
    exit 1
fi

# Validate VM
if [[ "$TARGET_VM" != "prod" && "$TARGET_VM" != "test" ]]; then
    echo "Error: VM must be 'prod' or 'test'"
    exit 1
fi

echo "=== Connecting channel #$CHANNEL_NAME to agent $AGENT_ID on $TARGET_VM ==="
echo ""
echo "NOTE: You must provide the Discord channel ID. To get it:"
echo "  1. Enable Developer Mode in Discord"
echo "  2. Right-click the channel -> 'Copy Channel ID'"
echo ""
read -p "Enter Discord Channel ID: " CHANNEL_ID

if [[ -z "$CHANNEL_ID" ]]; then
    echo "Error: Channel ID is required"
    exit 1
fi

# Execute on target VM
ssh "$TARGET_VM" << EOF
set -euo pipefail

CONFIG_FILE="\$HOME/.openclaw/openclaw.json"
BACKUP_FILE="\$HOME/.openclaw/openclaw.json.backup-\$(date +%Y%m%d-%H%M%S)"

echo "--- Step 1: Backup current config ---"
cp "\$CONFIG_FILE" "\$BACKUP_FILE"
echo "Backup saved to \$BACKUP_FILE"
echo ""

echo "--- Step 2: Add channel to channels section ---"
# Add channel entry if it doesn't exist
if ! grep -q "\"$CHANNEL_NAME\"" "\$CONFIG_FILE"; then
    # Use jq to add the channel
    jq --arg channel "$CHANNEL_NAME" \
       '.channels[\$channel] = {"requireMention": false}' \
       "\$CONFIG_FILE" > "\$CONFIG_FILE.tmp"
    mv "\$CONFIG_FILE.tmp" "\$CONFIG_FILE"
    echo "Added channel $CHANNEL_NAME to config"
else
    echo "Channel $CHANNEL_NAME already exists in config"
fi
echo ""

echo "--- Step 3: Add route binding for agent ---"
# Check if binding already exists
if grep -q "\"agentId\": \"$AGENT_ID\"" "\$CONFIG_FILE"; then
    echo "Warning: Binding for agent $AGENT_ID already exists"
else
    # Add the route binding at the beginning of bindings array
    jq --arg agentId "$AGENT_ID" \
       --arg channel "$CHANNEL_NAME" \
       --arg channelId "$CHANNEL_ID" \
       '.bindings = [{
           "type": "route",
           "agentId": \$agentId,
           "match": {
             "channel": "discord",
             "peer": {"kind": "channel", "id": \$channelId}
           }
         }] + .bindings' \
       "\$CONFIG_FILE" > "\$CONFIG_FILE.tmp"
    mv "\$CONFIG_FILE.tmp" "\$CONFIG_FILE"
    echo "Added route binding for $AGENT_ID"
fi
echo ""

echo "--- Step 4: Restart OpenCLAW Gateway ---"
pkill -f 'openclaw gateway' || true
sleep 2
cd "\$HOME"
nohup openclaw gateway > /tmp/openclaw-gateway.log 2>&1 &
sleep 3

if pgrep -f 'openclaw gateway' > /dev/null; then
    echo "OpenCLAW gateway restarted"
else
    echo "Warning: Gateway may not have started correctly"
fi
echo ""

echo "=== Channel Connection Complete ==="
echo "Channel:  #$CHANNEL_NAME (ID: $CHANNEL_ID)"
echo "Agent:    $AGENT_ID"
echo "Target:   $TARGET_VM"
EOF

echo ""
echo "Done! Channel #$CHANNEL_NAME is now connected to agent $AGENT_ID on $TARGET_VM"