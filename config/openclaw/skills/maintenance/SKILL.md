---
name: maintenance-commands
description: Parse maintenance commands for VM management
trigger: always
---

# Maintenance Commands

You understand natural language commands for managing VMs and translate them to script invocations.

## Command Patterns

### Add Repository
- "add repo `<owner>/<repo>` to `<prod|test>`"
- "clone `<owner>/<repo>` to `<prod|test>`"
- "setup `<owner>/<repo>` on `<prod|test>`"

**Action:** Run `scripts/maintenance/add-repo-to-vm.sh --repo <owner/repo> --vm <prod|test>`

### List Repositories
- "list repos on `<prod|test>`"
- "show repos on `<prod|test>`"
- "what repos are on `<prod|test>`"

**Action:** Run `scripts/maintenance/list-repos.sh <prod|test>`

### VM Status
- "status of `<prod|test>`"
- "check `<prod|test>`"
- "health of `<prod|test>`"

**Action:** Run `scripts/maintenance/vm-status.sh <prod|test>`

### Restart OpenCLAW
- "restart openclaw on `<prod|test>`"
- "restart gateway on `<prod|test>`"

**Action:** Run `scripts/maintenance/restart-openclaw.sh <prod|test>`

### Connect Channel
- "connect channel `<channel-name>` to `<prod|test>`"
- "map `<channel-name>` to `<prod|test>`"

**Action:** Run `scripts/maintenance/connect-channel.sh --channel <channel-name> --agent <channel-name> --vm <prod|test>`

## Response Formatting

After running any command, format the output for Discord:
- Use code blocks for command output
- Keep responses concise but informative
- If an error occurs, explain what happened and suggest next steps

## Examples

**User:** "add repo patelmm79/my-new-repo to prod"

**You:**
I'll add the repository to the prod VM. This will clone it and set up the 1:1:1 OpenCLAW configuration.

Running: `scripts/maintenance/add-repo-to-vm.sh --repo patelmm79/my-new-repo --vm prod`

[... output ...]

Done! The repository has been added to prod. Next steps:
1. Create Discord channel #my-new-repo
2. Run `./connect-channel.sh --channel my-new-repo --agent my-new-repo --vm prod`

---

**User:** "status of prod"

**You:**
Checking the status of the prod VM...

Running: `scripts/maintenance/vm-status.sh prod`

[... output ...]

The prod VM is healthy. OpenCLAW is running and there are no recent crashes.