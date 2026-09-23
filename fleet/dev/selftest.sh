#!/usr/bin/env bash
# ==================================================================================================
# Fleet - Self-test (toolkit *_TEST.sh)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-01 | Modified: 2026-09-23
# ==================================================================================================
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOOLKIT="${REPO}/fleet/toolkit"

AGE="$(command -v age-keygen || true)"
SOPS="$(command -v sops || true)"
if [[ -z "$AGE" ]]; then
    AGE="$(find /nix/store -maxdepth 4 -type f -name age-keygen 2>/dev/null | head -1)"
fi
if [[ -z "$SOPS" ]]; then
    SOPS="$(find /nix/store -maxdepth 4 -type f -name sops 2>/dev/null | head -1)"
fi
[[ -n "$AGE" && -n "$SOPS" ]] || {
    echo "need age-keygen and sops" >&2
    exit 1
}
export PATH="$(dirname "$AGE"):$(dirname "$SOPS"):$PATH"
export AGE SOPS
export ROOT="$TOOLKIT"
export TCAST_TOOLKIT_ROOT="$TOOLKIT"

exec bash "${REPO}/utilities/bashTestSuite/main.sh" "${TOOLKIT}/tests" "$@"
