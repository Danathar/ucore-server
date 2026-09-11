#!/usr/bin/env bash
# Render ucore-llm.bu into an Ignition config, injecting an ssh public key
# from this host. Nothing personal is committed to the repo -- the .bu file
# carries a @SSH_PUBKEY@ placeholder and the generated .ign is gitignored.
#
# Usage:
#   ./render.sh                          # uses ~/.ssh/id_ed25519.pub
#   ./render.sh ~/.ssh/some_other.pub
#   ./render.sh - < some.pub             # read the key from stdin
set -euo pipefail

cd "$(dirname "$0")"

BU=ucore-llm.bu
IGN=ucore-llm.ign
KEYFILE="${1:-$HOME/.ssh/id_ed25519.pub}"
BUTANE_IMAGE="${BUTANE_IMAGE:-quay.io/coreos/butane:release}"

if [[ "$KEYFILE" == "-" ]]; then
  PUBKEY="$(cat)"
else
  [[ -r "$KEYFILE" ]] || { echo "no readable public key at $KEYFILE" >&2; exit 1; }
  PUBKEY="$(cat "$KEYFILE")"
fi

# Guard against pointing this at a private key by mistake.
case "$PUBKEY" in
  ssh-ed25519\ *|ssh-rsa\ *|ecdsa-sha2-*|sk-ssh-*|sk-ecdsa-*) ;;
  *) echo "that does not look like an ssh PUBLIC key -- refusing" >&2; exit 1 ;;
esac

runner=$(command -v podman || command -v docker) || {
  echo "need podman or docker to run butane" >&2; exit 1; }

awk -v key="$PUBKEY" '{ gsub(/@SSH_PUBKEY@/, key); print }' "$BU" \
  | "$runner" run --rm -i "$BUTANE_IMAGE" --strict > "$IGN"

echo "wrote $(pwd)/$IGN"
