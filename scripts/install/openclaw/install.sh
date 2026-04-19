#!/bin/bash
# OpenCLAW installation: install, wrapper setup, npm cleanup
# Source this from ai-tools.sh

set -euo pipefail

# Resolve lib.sh from scripts/lib/ (sibling to scripts/install/)
_lib_sh_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd -P)/scripts/deploy"
# shellcheck source=../deploy/lib.sh
source "${_lib_sh_dir}/lib.sh"

cleanup_openclaw_npm() {
    log_info "Cleaning up old OpenCLAW npm artifacts..."

    local npm_global_path
    npm_global_path=$(npm root -g 2>/dev/null || echo "/usr/lib/node_modules")

    if [[ -d "$npm_global_path/openclaw" ]]; then
        rm -rf "$npm_global_path/openclaw"
        log_info "Removed old OpenCLAW npm package"
    fi

    rm -f /usr/bin/openclaw 2>/dev/null || true
    rm -f /usr/local/bin/openclaw 2>/dev/null || true
    npm cache clean --force 2>/dev/null || true

    log_info "NPM cleanup complete"
}

get_latest_openclaw_version() {
    npm show openclaw version 2>/dev/null || echo ""
}

install_openclaw() {
    log_step "Installing OpenCLAW..."

    local OPENCLAW_VERSION="${OPENCLAW_VERSION:-2026.04.11}"

    if command -v openclaw &> /dev/null; then
        local oc_version
        oc_version=$(openclaw --version 2>/dev/null || echo "installed")
        if [[ "$oc_version" == *"$OPENCLAW_VERSION"* ]]; then
            log_info "OpenCLAW already installed: $oc_version"
            return 0
        else
            log_warn "OpenCLAW version mismatch: $oc_version, reinstalling to $OPENCLAW_VERSION..."
            cleanup_openclaw_npm
        fi
    fi

    if ! command -v node &> /dev/null; then
        log_info "Installing Node.js for OpenCLAW..."
        if ! apt-get install -y nodejs npm 2>&1 | grep -q "Err\|Failed"; then
            log_info "Node.js installed"
            cleanup_openclaw_npm
        else
            log_warn "Failed to install Node.js"
        fi
    fi

    if command -v npm &> /dev/null; then
        if npm install -g "openclaw@$OPENCLAW_VERSION" 2>&1; then
            if command -v openclaw &> /dev/null; then
                log_info "OpenCLAW installed successfully"
            else
                local npm_global_path
                npm_global_path=$(npm root -g 2>/dev/null)
                if [ -f "$npm_global_path/openclaw/bin/openclaw.js" ]; then
                    ln -sf "$npm_global_path/openclaw/bin/openclaw.js" /usr/bin/openclaw 2>/dev/null || true
                fi
                if command -v openclaw &> /dev/null; then
                    log_info "OpenCLAW installed successfully"
                else
                    log_warn "OpenCLAW npm package installed but command not found"
                fi
            fi
        else
            log_warn "Failed to install OpenCLAW via npm"
        fi
    else
        log_warn "npm not available - cannot install OpenCLAW"
    fi
}

setup_openclaw_wrapper() {
    log_step "Setting up OpenCLAW wrapper..."

    local wrapper_path="/usr/local/bin/openclaw-wrapper"
    cat > "$wrapper_path" << 'EOF'
#!/bin/bash
# OpenCLAW wrapper - ensures environment variables are set

if [[ -f "$HOME/.bashrc" ]]; then
    source "$HOME/.bashrc" 2>/dev/null || true
fi

if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
    echo "Error: OPENROUTER_API_KEY not set"
    exit 1
fi

exec openclaw "$@"
EOF

    chmod +x "$wrapper_path"
    log_info "OpenCLAW wrapper created at $wrapper_path"
}

export -f cleanup_openclaw_npm get_latest_openclaw_version install_openclaw setup_openclaw_wrapper
