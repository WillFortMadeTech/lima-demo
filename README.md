# lima-demo

Runs Claude Code inside a fresh Ubuntu VM using Lima.

```bash
./lima-claude.sh [project-directory]
```

## Managing the VM

```bash
limactl shell claude-sandbox          # get back in, then run claude
limactl stop claude-sandbox           # stop it
limactl start claude-sandbox          # start it again
limactl delete --force claude-sandbox # remove it
limactl list                          # see what's running
```

## Before you run it

- **Every run deletes all existing Lima VMs**
- The project folder is mounted writable, so Claude's changes land on your Mac.
- With no folder given, nothing from your Mac is mounted.
- The VM has full internet access and can reach your Mac via `host.lima.internal`.
- Quitting Claude leaves you in a shell inside the VM. Type `exit` to get back to your Mac.
- You log in to Claude again on every run, as the VM is rebuilt each time.
