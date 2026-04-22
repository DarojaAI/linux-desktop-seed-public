#!/bin/bash
# scripts/maintenance/vm-status.sh
# Check health status of target VM (prod or test)

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

echo "=== VM Status: $TARGET_VM ==="
echo ""

# Check if VM is reachable
echo "--- Connectivity ---"
if ssh -o ConnectTimeout=5 "$TARGET_VM" "echo 'VM is reachable'" 2>/dev/null; then
    echo "✓ $TARGET_VM is online"
else
    echo "✗ $TARGET_VM is unreachable"
    exit 1
fi
echo ""

# Get system info via SSH
ssh "$TARGET_VM" << 'EOF'
echo "--- System Info ---"
echo "Hostname: $(hostname)"
echo "Uptime:   $(uptime -p)"
echo ""

echo "--- Memory Usage ---"
free -h | grep -E "Mem|Swap"
echo ""

echo "--- Disk Usage ---"
df -h / | tail -1
echo ""

echo "--- OpenCLAW Status ---"
if pgrep -f 'openclaw gateway' > /dev/null; then
    echo "✓ OpenCLAW gateway is running"
    ps aux | grep 'openclaw gateway' | grep -v grep | awk '{print "  PID: " $2 " | CMD: " $11 " " $12 " " $13}'
else
    echo "✗ OpenCLAW gateway is NOT running"
fi
echo ""

echo "--- xrdp Status ---"
if systemctl is-active --quiet xrdp 2>/dev/null; then
    echo "✓ xrdp is active"
else
    echo "✗ xrdp is not active"
fi
echo ""

echo "--- Session Monitor Status ---"
if systemctl is-active --quiet xrdp-session-monitor 2>/dev/null; then
    echo "✓ Session monitor is active"
else
    echo "✗ Session monitor is not active"
fi
echo ""

echo "--- Recent Crashes (last 24h) ---"
LOG_FILE="/var/log/xrdp/session-alerts.log"
if [[ -f "$LOG_FILE" ]]; then
    CRASH_COUNT=$(grep -c "CRASH\|SEGV\|SIGABRT" "$LOG_FILE" 2>/dev/null || echo "0")
    if [[ "$CRASH_COUNT" -gt 0 ]]; then
        echo "⚠ Found $CRASH_COUNT crash events in last 24h"
        grep "CRASH\|SEGV\|SIGABRT" "$LOG_FILE" | tail -3
    else
        echo "No recent crashes detected"
    fi
else
    echo "No alert log found"
fi
EOF