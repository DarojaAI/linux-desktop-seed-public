# Head Environment as Maintenance Controller - Transition Plan

## Context

You currently have two production VMs:
- **prod** (204.168.182.32) - Production workloads
- **test** (95.217.10.37) - Testing configurations

Both are managed manually via SSH. You also have a GitHub Actions workflow with an environment dropdown (head/prod/test) but it's not fully wired.

**Goal:** Make the **head** environment (deployed via GitHub Actions + Terraform) the central maintenance controller that manages prod and test VMs. This creates a unified operational model where head handles all maintenance tasks.

## What's Already Done

Based on exploration, there's already a detailed plan in `docs/superpowers/plans/2026-04-21-vm-maintenance-controller-plan.md` covering:
- SSH setup scripts (`setup-ssh-access.sh`)
- VM status scripts (`vm-status.sh`)
- List repos, restart OpenCLAW, connect-channel scripts
- OpenCLAW maintenance skill
- TDD tests with bats-core

The maintenance scripts exist in `scripts/maintenance/` and work via SSH from head to prod/test.

## What Needs to Be Done

### Phase 1: Infrastructure Setup (Context-Specific)

These items are NOT in the repository - they're configured on head VM after deployment:

| Item | Description | Where |
|------|-------------|-------|
| SSH keys | Ed25519 key pair generated on head | `~/.ssh/` on head |
| SSH config | Aliases for prod/test VMs | `~/.ssh/config` on head |
| Key distribution | `ssh-copy-id` to target VMs | Manual once |
| Discord channel bindings | Channel → agent mappings | OpenCLAW config |

**Manual steps after head VM deployment:**
```bash
# 1. Generate SSH key on head
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "head-maintenance"

# 2. Configure SSH aliases
cat >> ~/.ssh/config << 'EOF'
Host prod
    HostName 204.168.182.32
    User root
    IdentityFile ~/.ssh/id_ed25519

Host test
    HostName 95.217.10.37
    User root
    IdentityFile ~/.ssh/id_ed25519
EOF

# 3. Distribute keys (run from head)
ssh-copy-id -i ~/.ssh/id_ed25519.pub prod
ssh-copy-id -i ~/.ssh/id_ed25519.pub test
```

### Phase 2: Repository Artifacts (In Repo)

These files already exist or need updating:

| File | Status | Action |
|------|--------|--------|
| `scripts/maintenance/setup-ssh-access.sh` | ✅ Exists | Use as-is |
| `scripts/maintenance/vm-status.sh` | ✅ Exists | Use as-is |
| `scripts/maintenance/add-repo-to-vm.sh` | ✅ Exists | Use as-is |
| `scripts/maintenance/list-repos.sh` | ✅ Exists | Use as-is |
| `scripts/maintenance/restart-openclaw.sh` | ✅ Exists | Use as-is |
| `scripts/maintenance/connect-channel.sh` | ✅ Exists | Use as-is |
| `config/openclaw/skills/maintenance/SKILL.md` | ✅ Exists | Update for head context |
| `scripts/monitor/cross-vm-monitor.sh` | ❌ Missing | Create new |

**New files to create:**

1. **`scripts/monitor/cross-vm-monitor.sh`** - Runs on head, checks prod/test availability
   ```bash
   # Checks prod/test every 5 minutes
   # Logs to /var/log/xrdp/cross-vm-monitor.log
   # Alerts if a VM goes offline
   ```

2. **Update `config/openclaw/skills/maintenance/SKILL.md`** - Add head as target:
   - "status of head" → check head VM itself
   - Already supports prod/test

### Phase 3: GitHub Actions Updates

**File:** `.github/workflows/deploy.yml`

Current state: Environment dropdown exists but hardcoded to "head"

Needed changes:
1. Make environment selection work for real (use `github.event.inputs.environment`)
2. Pass environment-specific secrets based on selection
3. Add VM_IP variable per environment in GitHub settings

```yaml
# GitHub Environment Variables needed:
# head:   VM_IP=<head-ip>
# prod:   VM_IP=204.168.182.32
# test:   VM_IP=95.217.10.37
```

### Phase 4: Dev-Nexus Integration

**How dev-nexus fits in:**
- Dev-nexus is a Discord channel mapped to the dev-nexus agent
- That agent runs on **head** VM (via OpenCLAW)
- When you message dev-nexus about maintenance, head executes via SSH

**Flow:**
```
You → #dev-nexus: "check status of prod"
  → dev-nexus agent on head
  → ssh prod "vm-status.sh"
  → Response in #dev-nexus
```

### Phase 5: Terraform Updates (Optional)

**File:** `terraform/main.tf`

Currently hardcoded to `key = "head/terraform.tfstate"`. Could make environment-aware, but not required for initial setup.

## Implementation Order

| Step | Description | Type | Status |
|------|-------------|------|--------|
| 1 | Deploy head VM via GitHub Actions | Context | ✅ Done |
| 2 | Set up SSH keys on head (manual) | Context | 🔄 In Progress |
| 3 | Distribute SSH keys to prod/test | Context | ⏳ Pending |
| 4 | Update maintenance SKILL.md for head | Repo | ⏳ Pending |
| 5 | Create cross-vm-monitor.sh | Repo | ⏳ Pending |
| 6 | Update deploy.yml for env selection | Repo | ⏳ Pending |
| 7 | Bind dev-nexus channel to head | Context | ⏳ Pending |
| 8 | Test: send command to dev-nexus | Verify | ⏳ Pending |

**SSH setup options documented in:** `docs-private/head-ssh-setup-options.md`

## Verification

1. **SSH connectivity from head:**
   ```bash
   ssh prod "hostname"  # Should return prod hostname
   ssh test "hostname"  # Should return test hostname
   ```

2. **Maintenance commands work:**
   ```bash
   # On head VM
   ./scripts/maintenance/vm-status.sh prod
   ./scripts/maintenance/vm-status.sh test
   ```

3. **Discord integration:**
   - Message #dev-nexus: "status of prod"
   - Should return prod VM status in channel

4. **Cross-VM monitoring:**
   ```bash
   ./scripts/monitor/cross-vm-monitor.sh
   # Should show prod/test status
   ```

## Trade-offs

| Decision | Trade-off |
|----------|-----------|
| Manual SSH setup | More secure (keys never in repo), but requires one manual step after head deploy |
| Head monitors prod/test | Uses SSH bandwidth, but 5-min intervals are lightweight |
| Dev-nexus as interface | Already configured, but requires head to be running |
| Single bot for all envs | Simpler, but traffic mixed. Alternative: separate bots per environment |

## Summary

The transition is mostly about:
1. **Deploying head** via existing GitHub Actions workflow
2. **Running SSH setup** manually on head (keys, config, distribution)
3. **Using existing scripts** in `scripts/maintenance/` - they already work
4. **Binding dev-nexus** to head so you can issue commands via Discord

The repo artifacts are already largely in place. The context-specific items (SSH keys, channel bindings, IPs) stay outside the repo as intended.