#!/bin/bash
# scripts/maintenance/list-repos.sh
# List cloned repositories on target VM

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

echo "=== Repositories on $TARGET_VM ==="
echo ""

ssh "$TARGET_VM" << 'EOF'
PROJECTS_DIR="$HOME/Projects"

if [[ ! -d "$PROJECTS_DIR" ]]; then
    echo "No Projects directory found"
    exit 0
fi

echo "Directory: $PROJECTS_DIR"
echo ""

# List each repo with details
for repo in "$PROJECTS_DIR"/*; do
    if [[ -d "$repo" ]]; then
        REPO_NAME=$(basename "$repo")

        # Check if it's a git repo
        if [[ -d "$repo/.git" ]]; then
            cd "$repo"
            REMOTE=$(git remote get-url origin 2>/dev/null || echo "no remote")
            CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
            LAST_COMMIT=$(git log -1 --format="%h - %s" 2>/dev/null | head -1 || echo "no commits")

            echo "📁 $REPO_NAME"
            echo "   Remote:  $REMOTE"
            echo "   Branch:  $CURRENT_BRANCH"
            echo "   Last:    $LAST_COMMIT"
            echo ""
        else
            echo "📁 $REPO_NAME (not a git repository)"
            echo ""
        fi
    fi
done

echo "--- OpenCLAW Agents ---"
AGENTS_DIR="$HOME/.openclaw/agents"
if [[ -d "$AGENTS_DIR" ]]; then
    for agent in "$AGENTS_DIR"/*; do
        if [[ -d "$agent" && -f "$agent/agent/config.json" ]]; then
            AGENT_NAME=$(basename "$agent")
            WORKSPACE=$(jq -r '.workspace.path // "unknown"' "$agent/agent/config.json" 2>/dev/null || echo "unknown")
            echo "  • $AGENT_NAME → $WORKSPACE"
        fi
    done
else
    echo "  No agents configured"
fi
EOF