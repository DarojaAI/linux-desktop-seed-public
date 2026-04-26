#!/bin/bash
# Common library functions for deployment scripts
# Sourced by all deployment modules

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "[INFO] $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "[WARN] $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "[ERROR] $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "[STEP] $1"; }

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Detect Ubuntu version
detect_ubuntu_version() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" != "ubuntu" ]]; then
            log_error "This script only supports Ubuntu, detected: $ID"
            exit 1
        fi
        UBUNTU_VERSION="$VERSION_ID"
        log_info "Detected Ubuntu $UBUNTU_VERSION"

        # Check supported versions
        case "$UBUNTU_VERSION" in
            20.04|22.04|24.04)
                log_info "Ubuntu version $UBUNTU_VERSION is supported"
                ;;
            *)
                log_warn "Ubuntu $UBUNTU_VERSION may not be fully tested"
                ;;
        esac

        # Ensure X11 allows any user (needed for RDP)
        if [[ ! -f /etc/X11/Xwrapper.config ]] || ! grep -q "allowed_users" /etc/X11/Xwrapper.config 2>/dev/null; then
            echo "allowed_users=any" > /etc/X11/Xwrapper.config
        fi
    else
        log_error "Cannot detect OS version"
        exit 1
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check if a package is installed
package_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

# Retry a command with exponential backoff
retry_command() {
    local max_attempts=${1:-3}
    local delay=${2:-2}
    shift 2
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if "$@"; then
            return 0
        fi
        log_warn "Attempt $attempt/$max_attempts failed, retrying in ${delay}s..."
        sleep $delay
        delay=$((delay * 2))
        ((attempt++))
    done

    return 1
}

# Add apt repository securely
add_apt_repo() {
    local repo="$1"
    local key_url="$2"

    if ! grep -q "^deb.*$repo" /etc/apt/sources.list.d/* 2>/dev/null; then
        log_info "Adding repository: $repo"
        if [[ -n "$key_url" ]]; then
            wget -q "$key_url" -O /usr/share/keyrings/"$(basename "$key_url")"
            echo "deb [signed-by=/usr/share/keyrings/$(basename "$key_url")] $repo" > /etc/apt/sources.list.d/"$(basename "$repo" .list)".list
        else
            add-apt-repository -y "$repo"
        fi
    fi
}

# Create directory if it doesn't exist
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_info "Created directory: $dir"
    fi
}

# Download file with retry
download_file() {
    local url="$1"
    local dest="$2"
    local max_attempts=${3:-3}

    log_info "Downloading: $url"
    if wget -q --show-progress --progress=bar:force:noscroll -O "$dest" "$url" 2>&1 || \
       wget -q -O "$dest" "$url"; then
        log_info "Downloaded: $dest"
        return 0
    else
        log_error "Failed to download: $url"
        return 1
    fi
}

# Verify directory exists, create if needed
verify_dir() {
    local dir="$1"
    local create_if_missing=${2:-true}

    if [[ -z "$dir" ]]; then
        log_error "verify_dir: No directory path provided"
        return 1
    fi

    if [[ -d "$dir" ]]; then
        return 0
    elif [[ "$create_if_missing" == "true" ]]; then
        if mkdir -p "$dir" 2>/dev/null; then
            log_info "Created directory: $dir"
            return 0
        else
            log_error "Failed to create directory: $dir"
            return 1
        fi
    else
        log_error "Directory does not exist: $dir"
        return 1
    fi
}

# Verify file exists
verify_file() {
    local file="$1"

    if [[ -z "$file" ]]; then
        log_error "verify_file: No file path provided"
        return 1
    fi

    if [[ -f "$file" ]]; then
        return 0
    else
        log_error "File does not exist: $file"
        return 1
    fi
}

# Verify command is available
verify_command() {
    local cmd="$1"

    if [[ -z "$cmd" ]]; then
        log_error "verify_command: No command provided"
        return 1
    fi

    if command -v "$cmd" &>/dev/null; then
        return 0
    else
        log_error "Command not found: $cmd"
        return 1
    fi
}

# Run command as specific user safely
run_as_user() {
    local user="$1"
    shift

    if [[ -z "$user" ]]; then
        log_error "run_as_user: No user specified"
        return 1
    fi

    if id "$user" &>/dev/null; then
        sudo -u "$user" "$@"
    else
        log_error "User does not exist: $user"
        return 1
    fi
}

# Validate that a path is safe (no dangerous characters)
validate_path() {
    local path="$1"
    local description="${2:-path}"

    if [[ -z "$path" ]]; then
        log_error "validate_path: No $description provided"
        return 1
    fi

    # Check for dangerous characters (escape $ to check literal)
    if [[ "$path" =~ [;&|`\$\(\){}*?<>] ]]; then
        log_error "Invalid characters in $description: $path"
        return 1
    fi

    # Check for path traversal attempts
    if [[ "$path" =~ \.\./ ]]; then
        log_error "Path traversal detected in $description: $path"
        return 1
    fi

    return 0
}