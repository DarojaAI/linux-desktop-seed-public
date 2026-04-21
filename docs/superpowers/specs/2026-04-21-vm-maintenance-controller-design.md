# VM-A Maintenance Controller Design

**Date:** 2026-04-21
**Status:** Approved
**Approach:** Direct SSH Execution (Approach A)

## Overview

Transform VM-A (head) into a maintenance controller that manages VM-B (prod) and VM-C (test) via Discord commands. Instead of running maintenance operations from the laptop, users will message VM-A on Discord to trigger operations on the target VMs.

## Architecture

```
You → Discord #prod-vm-maintenance
      ↓
VM-A (head) ───SSH──→ VM-B (prod) ──→ Clone + OpenCLAW 1:1:1 + channel map
      ↓
VM-A (head) ───SSH──→ VM-C (test) ──→ Clone + OpenCLAW 1:1:1 + channel map
```

### Components on VM-A

1. **Discord Gateway** — Listens to #prod-vm-maintenance channel
2. **OpenCLAW Gateway** — Runs maintenance agent
3. **Maintenance Controller** — Bash scripts for remote operations
4. **SSH Key Manager** — Manages passwordless SSH access

## Supported Commands

| Command | Description |
|---------|-------------|
| `add repo <github-org/repo> to <prod\|test>` | Clone repo, set up OpenCLAW, map channel |
| `list repos on <prod\|test>` | Show cloned repos on target VM |
| `status of <prod\|test>` | Health check, uptime, memory |
| `restart openclaw on <prod\|test>` | Restart OpenCLAW gateway on target |
| `connect channel <name> to <prod\|test>` | Map new Discord channel to repo |

## SSH Passwordless Access

### Step 1: Generate SSH Key on VM-A

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -c "vm-a-maintenance"
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
```

### Step 2: SSH Config Aliases

```ssh
# ~/.ssh/config
Host prod
    HostName <VM-B-IP>
    User desktopuser
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new

Host test
    HostName <VM-C-IP>
    User desktopuser
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new
```

### Step 3: Distribute Public Key

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub prod
ssh-copy-id -i ~/.ssh/id_ed25519.pub test
```

## 1:1:1 Repo Setup Process

For each repo added to a target VM:

1. **Clone** — `git clone https://github.com/owner/repo.git ~/Projects/repo`
2. **Create Agent Directory** — `~/.openclaw/agents/{repo}/agent/{memory,sessions,mcp-servers}`
3. **Copy models.json** — From main agent
4. **Create config.json** — With model, workspace, repoUrl
5. **Copy auth-profiles.json** — From main agent
6. **Set permissions** — `chown desktopuser:desktopuser`, `chmod 700 memory`

## Discord Channel Binding

1. Create Discord channel manually
2. Get channel ID
3. Update openclaw.json bindings on target VM
4. Restart OpenCLAW gateway

## File Structure on VM-A

```
/home/desktopuser/
├── .openclaw/
│   ├── agents/main/agent/
│   │   └── SKILL.md          # Maintenance commands skill
│   └── logs/
│       └── maintenance.log
├── .ssh/
│   ├── id_ed25519
│   ├── id_ed25519.pub
│   └── config               # SSH aliases
└── maintenance-scripts/
    ├── add-repo-to-vm.sh
    ├── list-repos.sh
    ├── vm-status.sh
    ├── restart-openclaw.sh
    └── connect-channel.sh
```

## Error Handling

| Scenario | Handling |
|----------|----------|
| SSH connection fails | Retry 3x, report "Cannot reach prod VM" |
| Git clone fails | Report "Clone failed - repo may not exist" |
| OpenCLAW setup fails | Report specific error, suggest manual cleanup |
| Channel binding fails | Report "Channel mapping failed - check bot permissions" |
| Target VM offline | Report "prod VM is offline" |

## Phase Rollout

| Phase | Description |
|-------|-------------|
| Phase 1 | SSH setup + basic commands (status, list-repos) |
| Phase 2 | Add repo automation (clone + 1:1:1 setup) |
| Phase 3 | Channel binding automation |
| Phase 4 | Test with VM-C (test) |

## Notes

- VM-A already has OpenCLAW configured (per existing deployment)
- VM-B (prod) and VM-C (test) already have repos and OpenCLAW setup
- This design extends VM-A to become the orchestrator
- The 1:1:1 pattern (repo:channel:agent) is already established in the codebase