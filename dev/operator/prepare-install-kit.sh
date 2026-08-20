#!/usr/bin/env bash
# ==================================================================================================
# DPS Bootstrap - Operator: prepare install kit (SSH key + env export)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-07
# Description:   Generate per-machine SSH key and register read-only on GitHub account
# Usage:         ./prepare-install-kit.sh <hostname>
# Requires:      gh CLI authenticated, ssh-keygen
# ==================================================================================================

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <hostname>" >&2
    echo "Example: $0 control-toolkit" >&2
    exit 1
fi

HOST="$1"
KIT_DIR="$(pwd)/nds-install-kit-${HOST}"
KEY_BASE="${KIT_DIR}/ssh_key"
TITLE="nds-${HOST}"

if ! command -v ssh-keygen &>/dev/null; then
    echo "Error: ssh-keygen not found in PATH" >&2
    exit 1
fi

if ! command -v gh &>/dev/null; then
    echo "Error: gh CLI not found — install and authenticate (gh auth login)" >&2
    exit 1
fi

mkdir -p "$KIT_DIR"
chmod 700 "$KIT_DIR"
rm -f "${KEY_BASE}" "${KEY_BASE}.pub"
ssh-keygen -t ed25519 -f "$KEY_BASE" -N "" -C "$TITLE"

gh api -X POST user/keys -f "title=${TITLE}" -f "key=$(tr -d '\n' < "${KEY_BASE}.pub")" -f "read_only=true" \
    || gh ssh-key add "${KEY_BASE}.pub" -t "$TITLE"
echo "Registered read-only account SSH key (${TITLE}) on GitHub"

cat > "${KIT_DIR}/README.txt" <<EOF
NDS install kit for ${HOST}
===========================

1. Copy ssh_key to the live ISO (USB or scp):
     scp ${KEY_BASE} nixos@<live-ip>:/tmp/nds-ssh-key

2. On the live ISO, before running NDS:
     export NDS_GIT_IMPORT_KEY_PATH="/tmp/nds-ssh-key"
     export NDS_FLAKE_REPO_URL="git@github.com:ORG/REPO.git"
     export NDS_FLAKE_HOST="${HOST}"
     export NDS_SKIP_MENU=true
     sudo -E bash src/app/main.sh --auto-confirm

After install, per-repo deploy keys are installed under /root/.ssh/nds_deploy_* with nds-git-ssh.

Public key (for reference):
$(cat "${KEY_BASE}.pub")
EOF

chmod 600 "${KEY_BASE}"
echo ""
echo "Install kit ready: ${KIT_DIR}"
echo "  ssh_key       — private key (copy to live ISO)"
echo "  ssh_key.pub   — public key"
echo "  README.txt    — operator steps"
