#!/usr/bin/env bash
# ==================================================================================================
# DPS Bootstrap - Operator: rotate sops age recipients
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-03 | Modified: 2026-07-03
# Description:   Re-encrypt all secrets in a flake with current .sops.yaml recipients
# Usage:         ./rotate-age-keys.sh [/path/to/flake]
# ==================================================================================================

set -euo pipefail

FLAKE_ROOT="${1:-.}"
cd "$FLAKE_ROOT"

if [[ ! -f .sops.yaml ]]; then
    echo "Error: no .sops.yaml in $(pwd)" >&2
    exit 1
fi

if ! command -v sops &>/dev/null; then
    echo "Error: sops not found in PATH" >&2
    exit 1
fi

echo "Re-encrypting all secrets with current .sops.yaml recipients..."

found=0
while IFS= read -r -d '' f; do
    sops updatekeys -y "$f"
    echo "Updated: $f"
    found=1
done < <(find secrets -type f \( -name '*.yaml' -o -name '*.yml' \) -print0 2>/dev/null || true)

if [[ "$found" -eq 0 ]]; then
    echo "No secrets/*.yaml or secrets/**/*.yaml files found under $(pwd)"
    exit 1
fi

echo "Done. Commit and push, then redeploy affected machines."
