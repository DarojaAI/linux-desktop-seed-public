# Deployment Troubleshooting Guide

This document covers common issues encountered when deploying the Linux Desktop via GitHub Actions + Terraform + Hetzner.

## Quick Checklist

Before running the workflow, verify:

- [ ] GitHub Environment "head" has **secrets**:
  - `HETZNER_API_TOKEN` - Hetzner API token
  - `SSH_PRIVATE_KEY` - Valid ed25519 private key (no passphrase)
- [ ] GitHub Environment "head" has **variables**:
  - `HETZNER_LOCATION` - Datacenter (fsn1, nbg1, hel1)
  - `SERVER_TYPE` - Server type (cx23, cpx41, etc.)
  - `HETZNER_SSH_KEY_NAME` - Name of SSH key in Hetzner console

## Common Issues

### SSH Connection Refused

**Symptom:** `ssh: connect to host X port 22: Connection refused`

**Causes:**
1. Server SSH key not attached during creation
2. Server not fully provisioned yet

**Fixes:**
- Ensure `HETZNER_SSH_KEY_NAME` variable matches the key name in Hetzner console
- The workflow now includes a "Wait for server to be ready" step that polls for SSH

### Permission Denied (Public Key)

**Symptom:** `root@X: Permission denied (publickey,password)`

**Causes:**
1. Private key in GitHub secret doesn't match the public key uploaded to Hetzner
2. SSH_PRIVATE_KEY secret is empty or malformed

**Debug:**
```bash
# In workflow logs, check:
=== Key first line ===      # Should be: -----BEGIN OPENSSH PRIVATE KEY-----
=== Key last line ===       # Should be: -----END OPENSSH PRIVATE KEY-----
=== Testing private key === # Should be: KEY_VALID
=== Byte count ===          # Should be ~1700 for ed25519
```

**Fix:** Ensure the secret contains the full private key with proper headers, no extra whitespace or trailing newlines.

### Server Limit Reached

**Symptom:** `Error: server limit reached (resource_limit_exceeded)`

**Cause:** Hetzner account has a server limit (usually 1-3 for free tier)

**Fix:** The workflow now includes a "Pre-destroy for apply" step that deletes existing `linux-desktop-*` servers before creating a new one.

### Secrets Not Available in Deploy Job

**Symptom:** SSH key shows as 1 byte or empty in deploy job logs

**Cause:** Environment secrets require the job to specify the environment

**Fix:** Add `environment: head` to the deploy job in `deploy.yml`:
```yaml
deploy:
  name: Deploy Desktop
  needs: terraform
  runs-on: ubuntu-latest
  environment: head  # Required for environment secrets
```

### Deployment Script Missing Files

**Symptom:** `/tmp/scripts/deploy/lib.sh: No such file or directory`

**Cause:** Only the main script was copied, not the supporting modules

**Fix:** Copy the entire scripts folder:
```yaml
- name: Copy deployment script and modules
  run: |
    scp -o StrictHostKeyChecking=no -r deploy-desktop.sh root@${{ env.SERVER_IP }}:/tmp/
    scp -o StrictHostKeyChecking=no -r scripts root@${{ env.SERVER_IP }}:/tmp/
```

### User Creation Failed

**Symptom:** `useradd: group 'admin' does not exist`

**Cause:** Ubuntu doesn't have an `admin` group by default (it's `sudo`)

**Fix:** In `scripts/deploy/system.sh`, use `sudo` instead of `admin`:
```bash
useradd -m -s /bin/bash -G sudo "$username"
```

### Claude Code Install Failed

**Symptom:** `npm ERR! SyntaxError: Unexpected token '.'` - Node.js v12 too old

**Cause:** Ubuntu 22.04 default repos have Node.js v12, but Claude Code requires v18+

**Fix:** Use NodeSource to install Node.js 20:
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
```

### Session Monitor Script Not Found

**Symptom:** `Session monitor script not found in repo`

**Cause:** Incorrect path to `session-monitor.sh` in deployment scripts

**Fix:** Use `$SCRIPT_DIR/scripts/` prefix:
```bash
local repo_script="$SCRIPT_DIR/scripts/session-monitor.sh"
local repo_analyze="$SCRIPT_DIR/scripts/analyze-session-logs.sh"
```

## Hetzner-Specific Notes

### SSH Key Format
- Upload the **public key** to Hetzner console
- Store the **private key** in GitHub secrets
- Key must be ed25519 or rsa (2048+ bit)
- No passphrase supported for GitHub Actions

### Server Types
- `cx23` - Basic (2 vCPU, 4GB RAM) - $5/mo
- `cpx21` - Standard (2 vCPU, 4GB RAM) - $7/mo
- `cpx41` - Performance (4 vCPU, 8GB RAM) - $14/mo

### Locations
- `fsn1` - Falkenstein, Germany
- `nbg1` - Nuremberg, Germany  
- `hel1` - Helsinki, Finland

## Debugging Commands

### Test SSH Key Locally
```bash
# Validate key format
ssh-keygen -y -f ~/.ssh/id_ed25519

# Check key byte count
wc -c < ~/.ssh/id_ed25519

# Show exact format (check for trailing newlines)
cat -A ~/.ssh/id_ed25519
```

### Check Hetzner Servers
```bash
hcloud server list
hcloud server list -o json | jq '.[] | {name, status, public_net.ipv4.ip}'
```

### Check Terraform State
```bash
cd terraform
terraform show
terraform output
```

## Pre-Flight Validation Script

Create a GitHub workflow that runs before deploy to validate configuration:

```yaml
validate-config:
  runs-on: ubuntu-latest
  steps:
    - name: Validate SSH key
      run: |
        echo "${{ secrets.SSH_PRIVATE_KEY }}" > /tmp/test_key
        chmod 600 /tmp/test_key
        ssh-keygen -y -f /tmp/test_key >/dev/null && echo "KEY_VALID" || exit 1

    - name: Validate Hetzner token
      run: |
        curl -sH "Authorization: Bearer ${{ secrets.HETZNER_API_TOKEN }}" \
          https://api.hetzner.cloud/v1/ssh_keys | jq .
```

---

**Last Updated:** April 2026