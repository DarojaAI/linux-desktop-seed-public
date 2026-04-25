#!/bin/bash
# Test OpenCLAW channel binding - automated validation
# Verifies that linux-desktop-seed agent is properly bound to Discord channel

set -euo pipefail

# Configuration
EXPECTED_CHANNEL_ID="1496398999928967238"
EXPECTED_AGENT_ID="linux-desktop-seed"
SSH_KEY="/c/Users/insan/.ssh/hetznertest.key"
HEAD_IP="178.105.6.47"

# Test results
PASSED=0
FAILED=0

log_pass() {
    echo "✅ PASS: $1"
    PASSED=$((PASSED + 1))
}

log_fail() {
    echo "❌ FAIL: $1"
    FAILED=$((FAILED + 1))
}

log_info() {
    echo "ℹ️  INFO: $1"
}

# Test 1: Check if OpenCLAW config exists
echo "=== Testing OpenCLAW Channel Binding ==="
echo ""

log_info "Test 1: Checking OpenCLAW config exists..."
CONFIG_FILE=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no root@$HEAD_IP "sudo -u desktopuser cat /home/desktopuser/.openclaw/openclaw.json 2>/dev/null" || echo "")
if [[ -n "$CONFIG_FILE" ]]; then
    log_pass "OpenCLAW config file exists"
else
    log_fail "OpenCLAW config file not found"
fi

# Test 2: Check if agent exists
log_info "Test 2: Checking agent exists..."
AGENT_EXISTS=$(echo "$CONFIG_FILE" | ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no root@$HEAD_IP "sudo -u desktopuser jq -r '.agents.list[] | select(.id == \"$EXPECTED_AGENT_ID\") | .id' 2>/dev/null" || echo "")
if [[ "$AGENT_EXISTS" == "$EXPECTED_AGENT_ID" ]]; then
    log_pass "Agent '$EXPECTED_AGENT_ID' exists"
else
    log_fail "Agent '$EXPECTED_AGENT_ID' not found in config"
fi

# Test 3: Check channel binding
log_info "Test 3: Checking channel binding..."
CHANNEL_ID=$(echo "$CONFIG_FILE" | ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no root@$HEAD_IP "sudo -u desktopuser jq -r '.bindings[] | select(.agentId == \"$EXPECTED_AGENT_ID\") | .match.peer.id' 2>/dev/null" || echo "")
if [[ "$CHANNEL_ID" == "$EXPECTED_CHANNEL_ID" ]]; then
    log_pass "Channel binding correct (ID: $CHANNEL_ID)"
else
    log_fail "Channel binding incorrect (expected: $EXPECTED_CHANNEL_ID, got: $CHANNEL_ID)"
fi

# Test 4: Check git remote is set correctly
log_info "Test 4: Checking git remote..."
GIT_REMOTE=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no root@$HEAD_IP "sudo -u desktopuser bash -c 'cd /home/desktopuser/GithubProjects/linux-desktop-seed && git remote get-url origin' 2>/dev/null" || echo "")
if [[ "$GIT_REMOTE" == "https://github.com/DarojaAI/linux-desktop-seed.git" ]]; then
    log_pass "Git remote correctly set to $GIT_REMOTE"
else
    log_fail "Git remote incorrect (expected: https://github.com/DarojaAI/linux-desktop-seed.git, got: $GIT_REMOTE)"
fi

# Test 5: Check git has commits (not just initialized)
log_info "Test 5: Checking git has commits..."
GIT_COMMITS=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no root@$HEAD_IP "sudo -u desktopuser bash -c 'cd /home/desktopuser/GithubProjects/linux-desktop-seed && git rev-list --count HEAD' 2>/dev/null" || echo "0")
if [[ "$GIT_COMMITS" -gt 0 ]]; then
    log_pass "Git repository has $GIT_COMMITS commit(s)"
else
    log_fail "Git repository has no commits"
fi

# Test 6: Check OpenCLAW gateway is running
log_info "Test 6: Checking OpenCLAW gateway is running..."
GATEWAY_RUNNING=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no root@$HEAD_IP "pgrep -f 'openclaw gateway' >/dev/null && echo 'running' || echo 'not_running'" 2>/dev/null || echo "error")
if [[ "$GATEWAY_RUNNING" == "running" ]]; then
    log_pass "OpenCLAW gateway is running"
else
    log_fail "OpenCLAW gateway is not running (status: $GATEWAY_RUNNING)"
fi

# Test 7: Check SSH config for maintenance
log_info "Test 7: Checking SSH maintenance config..."
SSH_CONFIG_TEST=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no root@$HEAD_IP "sudo -u desktopuser bash -c 'grep -q \"Host prod\" ~/.ssh/config && echo \"prod_configured\" || echo \"prod_missing\"' 2>/dev/null" || echo "error")
if [[ "$SSH_CONFIG_TEST" == "prod_configured" ]]; then
    log_pass "SSH config has prod entry"
else
    log_fail "SSH config missing prod entry"
fi

# Summary
echo ""
echo "=== Test Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo "🎉 All tests passed!"
    exit 0
else
    echo "⚠️  $FAILED test(s) failed"
    exit 1
fi
