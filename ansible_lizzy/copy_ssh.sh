#!/usr/bin/env bash
set -euo pipefail

INV_FILE="${1:-inventories/production/remote.yml}"
PUBKEY="${SSH_PUBKEY:-$HOME/.ssh/id_ed25519.pub}"

if [[ ! -f "$INV_FILE" ]]; then
  echo "Inventory not found: $INV_FILE" >&2
  exit 1
fi
if [[ ! -f "$PUBKEY" ]]; then
  echo "Public key not found: $PUBKEY" >&2
  exit 1
fi

echo "Using inventory: $INV_FILE"
echo "Using public key: $PUBKEY"
echo

# Emit "host port" lines, one per target
emit_targets() {
  if command -v yq >/dev/null 2>&1; then
    # mikefarah/yq
    yq -r '
      .. | .hosts? // empty
      | to_entries[]
      | "\(.value.ansible_host // .key) \(.value.ansible_port // 22)"
    ' "$INV_FILE"
    return
  fi

  if python3 - <<'PY' >/dev/null 2>&1; then
import sys, yaml  # type: ignore
PY
  then
    python3 - "$INV_FILE" <<'PY'
import sys, yaml
path = sys.argv[1]
data = yaml.safe_load(open(path))
targets = []
def walk(node):
    if isinstance(node, dict):
        hosts = node.get('hosts')
        if isinstance(hosts, dict):
            for name, vars in hosts.items():
                vars = vars or {}
                host = vars.get('ansible_host', name)
                port = vars.get('ansible_port', 22)
                print(f"{host} {port}")
        for v in node.values():
            walk(v)
walk(data)
PY
    return
  fi

  # Fallback: simple grep/sed for the structure shown in the question.
  # (Uses the top-level "all: hosts:" map; ignores nested groups and custom ports.)
  awk '
    $1 == "hosts:" { inhosts=1; next }
    inhosts && $1 ~ /^[^:]+:$/ {
      gsub(":", "", $1); host=$1
      print host, 22
    }
    inhosts && $1 == "" { next }
  ' "$INV_FILE"
}

# Iterate and copy the key
while read -r HOST PORT; do
  [[ -z "$HOST" ]] && continue
  echo ">>> Copying key to root@${HOST} (port ${PORT})"
  # Add StrictHostKeyChecking=accept-new to avoid interactivity on first connect
  if [[ -n "${SSHPASS:-}" ]]; then
    # Optional non-interactive mode if SSHPASS is set and sshpass is installed
    if command -v sshpass >/dev/null 2>&1; then
      sshpass -p "$SSHPASS" ssh-copy-id -p "$PORT" -i "$PUBKEY" \
        -o StrictHostKeyChecking=accept-new root@"$HOST" || {
          echo "Failed: root@${HOST}" >&2; continue; }
    else
      echo "Warning: SSHPASS set but sshpass not installed; falling back to interactive prompt." >&2
      ssh-copy-id -p "$PORT" -i "$PUBKEY" -o StrictHostKeyChecking=accept-new root@"$HOST" || {
        echo "Failed: root@${HOST}" >&2; continue; }
    fi
  else
    ssh-copy-id -p "$PORT" -i "$PUBKEY" -o StrictHostKeyChecking=accept-new root@"$HOST" || {
      echo "Failed: root@${HOST}" >&2; continue; }
  fi
done < <(emit_targets)

echo
echo "All done."
