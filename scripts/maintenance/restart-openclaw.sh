#!/bin/bash
# scripts/maintenance/restart-openclaw.sh
# Restart OpenCLAW gateway on target VM

set -euo pipefail

TARGET_VM="${1:-}"
if [[ -z "$TARGET_VM" ]]; then
    echo "Usage: $0 <prod|test>"
    exit 1
fi

# Validate VM
if [[ "$TARGET_VM" != "prod" && "$TARGET_VM" != "test" ]]; then
    echo "Error: VM must be 'prod' or 'test'"
    exit 1
fi

echo "=== Restarting OpenCLAW on $TARGET_VM ==="

# Kill existing gateway
echo "Stopping existing gateway..."
ssh "$TARGET_VM" "pkill -f 'openclaw gateway' || true"

# Wait a moment
sleep 2

# Start new gateway
echo "Starting gateway..."
ssh "$TARGET_VM" << 'EOF'
cd "$HOME"
nohup openclaw gateway > /tmp/openclaw-gateway.log 2>&1 &
sleep 3

# Verify it's running
if pgrep -f 'openclaw gateway' > /dev/null; then
    echo "OpenCLAW gateway started successfully"
    ps aux | grep 'openclaw gateway' | grep -v grep | awk '{print "  PID: " $2}'
else
    echo "Failed to start OpenCLAW gateway"
    echo "Check logs: tail -50 /tmp/openclaw-gateway.log"
    exit 1
fi
EOF

echo "Done! OpenCLAW on $TARGET_VM has been restarted."