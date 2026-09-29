#!/usr/bin/env bash
set -euo pipefail

VM_NAME="claude-sandbox"

usage() {
  echo "Usage: $(basename "$0") [project-directory]"
  echo
  echo "Creates a fresh Ubuntu Lima VM with Claude Code installed."
  echo "If a project directory is given, it is mounted writable at ~/<project-name> in the VM."
  echo "If not, nothing from your Mac is mounted."
  echo
  echo "Warning: every existing Lima VM is deleted on each run."
}

log() {
  printf '\n==> %s\n' "$1"
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 1 ]]; then
  usage
  exit 1
fi

[[ "$(uname -s)" == "Darwin" ]] || fail "this script is for macOS."
command -v brew >/dev/null 2>&1 || fail "Homebrew is not installed. See https://brew.sh"

PROJECT_DIR=""
PROJECT_NAME=""
if [[ $# -eq 1 ]]; then
  [[ -d "$1" ]] || fail "'$1' is not a directory."
  PROJECT_DIR="$(cd "$1" && pwd -P)"
  PROJECT_NAME="$(basename "$PROJECT_DIR")"
  [[ "$PROJECT_DIR" != "/" ]] || fail "refusing to mount the root filesystem."
fi

if command -v limactl >/dev/null 2>&1; then
  log "Lima already installed ($(limactl --version))"
else
  log "Installing Lima with Homebrew"
  brew install lima
fi

log "Removing existing Lima VMs"
EXISTING="$(limactl list -q 2>/dev/null || true)"
if [[ -z "$EXISTING" ]]; then
  echo "None found."
else
  while IFS= read -r instance; do
    [[ -n "$instance" ]] || continue
    echo "Deleting $instance"
    limactl delete --force "$instance"
  done <<< "$EXISTING"
fi

CREATE_ARGS=(--name "$VM_NAME" --tty=false)
if [[ -n "$PROJECT_DIR" ]]; then
  escaped_dir="$(printf '%s' "$PROJECT_DIR" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  escaped_name="$(printf '%s' "$PROJECT_NAME" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  CREATE_ARGS+=(--set ".mounts = [{\"location\": \"$escaped_dir\", \"mountPoint\": \"{{.Home}}/$escaped_name\", \"writable\": true}]")
  log "Creating VM '$VM_NAME' with $PROJECT_DIR mounted at ~/$PROJECT_NAME"
else
  CREATE_ARGS+=(--mount-none)
  log "Creating VM '$VM_NAME' with no mounts"
fi

limactl create "${CREATE_ARGS[@]}" template:ubuntu

log "Starting VM (first boot takes a minute or two)"
limactl start --tty=false "$VM_NAME"

log "Installing Claude Code inside the VM"
limactl shell --workdir / "$VM_NAME" bash -lc '
  set -euo pipefail
  curl -fsSL https://claude.ai/install.sh | bash
  grep -q "HOME/.local/bin" "$HOME/.bashrc" || echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$HOME/.bashrc"
'

GUEST_HOME="$(limactl shell --workdir / "$VM_NAME" printenv HOME)"
WORKDIR="$GUEST_HOME"
if [[ -n "$PROJECT_NAME" ]]; then
  WORKDIR="$GUEST_HOME/$PROJECT_NAME"
fi

log "Ready"
echo "VM:       $VM_NAME"
echo "Workdir:  $WORKDIR"
if [[ -n "$PROJECT_DIR" ]]; then
  echo "Mounted:  $PROJECT_DIR -> $WORKDIR (writable)"
else
  echo "Mounted:  nothing"
fi
echo
echo "Reconnect later with: limactl shell --workdir \"$WORKDIR\" $VM_NAME"
echo "Delete the VM with:   limactl delete --force $VM_NAME"

log "Launching Claude Code"
exec limactl shell --workdir "$WORKDIR" "$VM_NAME" bash -lc 'export PATH="$HOME/.local/bin:$PATH"; claude; echo; echo "Claude exited. You are still in the VM. Type exit to leave."; exec bash -l'
