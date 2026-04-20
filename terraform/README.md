# Terraform - Hetzner Server Provisioning

Provisions a single VM on Hetzner for the Linux desktop deployment.

## Quick Start

### 1. Create Hetzner API Token

1. Log into [Hetzner Console](https://console.hetzner.com)
2. Select your project
3. Go to **Security** → **API Tokens**
4. Create a new token (read/write permissions)
5. Copy the token immediately (shown only once)

### 2. Add SSH Key to Hetzner

1. Go to **SSH Keys** in Hetzner Console
2. Add your public key (`~/.ssh/id_ed25519.pub` or `~/.ssh/id_rsa.pub`)
3. Note the key name (e.g., "my-laptop")

### 3. Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
hcloud_token = "your-api-token-here"
server_name  = "linux-desktop"
server_type  = "cpx41"   # 4 vCPU, 8GB RAM
location     = "fsn1"    # Falkenstein
image        = "ubuntu-22.04"
ssh_keys     = ["my-ssh-key"]
```

### 4. Deploy

```bash
# Initialize
terraform init

# Preview
terraform plan

# Apply
terraform apply
```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `hcloud_token` | (required) | Hetzner API token |
| `ssh_private_key` | "" | Private key for remote-exec |
| `server_name` | "linux-desktop" | Server hostname |
| `server_type` | "cpx41" | Hetzner server type |
| `location` | "fsn1" | Datacenter |
| `image` | "ubuntu-22.04" | OS image |
| `ssh_keys` | [] | SSH key names to attach |

## Server Types

| Type | vCPU | RAM | Good For |
|------|------|-----|----------|
| `cpx21` | 2 | 4GB | Testing |
| `cpx41` | 4 | 8GB | Desktop |
| `cpx61` | 8 | 16GB | Heavy use |

## Outputs

After apply, run:
```bash
terraform output ipv4_address
```

This gives you the IP to connect to via RDP (port 3389).