#!/bin/bash
# scripts/maintenance/setup-ssh-access.sh
# Sets up passwordless SSH from VM-A to VM-B (prod) and VM-C (test)

set -euo pipefail

SSH_DIR="$HOME/.ssh"
KEY_FILE="$SSH_DIR/id_ed25519"
CONFIG_FILE="$SSH_DIR/config"

usage() {
    echo "Usage: $0 --vm prod|test --host <hostname-or-ip>"
    echo "Example: $0 --vm prod --host 192.168.1.100"
    exit 1
}

# Parse arguments
VM=""
HOST=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --vm)
            VM="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

if [[ -z "$VM" || -z "$HOST" ]]; then
    usage
fi

# Validate VM is prod or test
if [[ "$VM" != "prod" && "$VM" != "test" ]]; then
    echo "Error: VM must be 'prod' or 'test'"
    usage
fi

echo "Setting up SSH access for VM: $VM ($HOST)"

# Create .ssh directory if it doesn't exist
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Generate SSH key if it doesn't exist
if [[ ! -f "$KEY_FILE" ]]; then
    echo "Generating new SSH key..."
    ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "vm-a-maintenance"
    chmod 600 "$KEY_FILE"
else
    echo "SSH key already exists at $KEY_FILE"
fi

# Add SSH config entry if not exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    touch "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
fi

# Check if config for this VM already exists
if ! grep -q "^Host $VM$" "$CONFIG_FILE"; then
    echo "Adding SSH config for $VM..."
    cat >> "$CONFIG_FILE" << EOF

Host $VM
    HostName $HOST
    User desktopuser
    IdentityFile $KEY_FILE
    StrictHostKeyChecking accept-new
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
else
    echo "SSH config for $VM already exists"
    sed -i "/^Host $VM$/,/^Host /{s/HostName .*/HostName $HOST/}" "$CONFIG_FILE"
fi

# Copy public key to target VM (optional - may fail in test scenarios)
echo "Distributing public key to $VM..."
if ssh-copy-id -i "${KEY_FILE}.pub" "$VM" 2>/dev/null; then
    echo "Public key distributed successfully"
else
    echo "Warning: ssh-copy-id failed. Manual key distribution may be needed."
    echo "Run: ssh-copy-id -i ${KEY_FILE}.pub $VM"
fi

# Verify connection (optional - may fail in test scenarios)
echo "Verifying SSH connection to $VM..."
if ssh -o ConnectTimeout=5 -o BatchMode=yes "$VM" "hostname" > /dev/null 2>&1; then
    echo "✓ SSH access to $VM configured successfully"
else
    echo "Note: Could not verify SSH connection. Key may need manual distribution."
    echo "SSH config has been created at $CONFIG_FILE"
fi

echo "Done! SSH access to $VM is configured."