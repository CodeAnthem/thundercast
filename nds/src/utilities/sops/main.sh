#!/usr/bin/env bash
# ==================================================================================================
# sops utility - machine age enroll (calls age/pkg; no prompts)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# ==================================================================================================

if (( BASH_VERSINFO[0] < 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] < 3) )); then
    printf 'SOPS: requires Bash 5.3 or newer (found %s).\n' "${BASH_VERSION}" >&2
    return 1 2>/dev/null || exit 1
fi

_SOPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for f in "${_SOPS_DIR}/ops"/*.sh; do
    [[ -f "$f" ]] || continue
    # shellcheck disable=SC1090
    source "$f"
done

sops_onLoad() { return 0; }
sops_onExit() { return 0; }
