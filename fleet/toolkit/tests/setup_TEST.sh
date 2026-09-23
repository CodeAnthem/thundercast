#!/usr/bin/env bash
# ==================================================================================================
# Fleet toolkit - test load (libs + age/sops)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-23 | Modified: 2026-09-23
# ==================================================================================================

_TOOLKIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ROOT="${ROOT:-$_TOOLKIT}"
export ROOT
export TCAST_TOOLKIT_ROOT="${TCAST_TOOLKIT_ROOT:-$ROOT}"

if [[ -z "${AGE:-}" ]]; then
    AGE="$(command -v age-keygen || true)"
fi
if [[ -z "${SOPS:-}" ]]; then
    SOPS="$(command -v sops || true)"
fi
if [[ -z "${AGE:-}" ]]; then
    AGE="$(find /nix/store -maxdepth 4 -type f -name age-keygen 2>/dev/null | head -1)"
fi
if [[ -z "${SOPS:-}" ]]; then
    SOPS="$(find /nix/store -maxdepth 4 -type f -name sops 2>/dev/null | head -1)"
fi
if [[ -z "${AGE:-}" || -z "${SOPS:-}" ]]; then
    bts_fail "need age-keygen and sops"
else
    export PATH="$(dirname "$AGE"):$(dirname "$SOPS"):${PATH}"
    export AGE SOPS
fi

# shellcheck source=../lib/core.sh
source "${ROOT}/lib/core.sh"
# shellcheck source=../lib/ui.sh
source "${ROOT}/lib/ui.sh"
# shellcheck source=../lib/register.sh
source "${ROOT}/lib/register.sh"
# shellcheck source=../lib/sops.sh
source "${ROOT}/lib/sops.sh"
# shellcheck source=../lib/git.sh
source "${ROOT}/lib/git.sh"
# shellcheck source=../lib/nodes.sh
source "${ROOT}/lib/nodes.sh"
# shellcheck source=../menus.sh
source "${ROOT}/menus.sh"
