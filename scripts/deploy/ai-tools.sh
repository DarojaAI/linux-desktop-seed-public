#!/bin/bash
# AI tools module: OpenCLAW, OpenRouter
# Source this from the main deploy script

set -euo pipefail

if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# shellcheck source=openclaw/install.sh
source "$_ai_dir/openclaw/install.sh"
# shellcheck source=openclaw/config.sh
source "$_ai_dir/openclaw/config.sh"
# shellcheck source=openclaw/governance.sh
source "$_ai_dir/openclaw/governance.sh"
=======
# Resolve openclaw scripts from scripts/install/openclaw/ (sibling to scripts/deploy/)
_ai_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../install" && pwd -P)"

# OpenCLAW is optional — source only if not disabled
if [[ "${LOAD_OPENCLAW:-true}" != "false" ]]; then
    # shellcheck source=openclaw/install.sh
    source "$_ai_dir/openclaw/install.sh"
    # shellcheck source=openclaw/config.sh
    source "$_ai_dir/openclaw/config.sh"
    # shellcheck source=openclaw/governance.sh
    source "$_ai_dir/openclaw/governance.sh"
fi

unset _ai_dir
