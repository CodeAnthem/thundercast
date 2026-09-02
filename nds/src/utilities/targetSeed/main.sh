#!/usr/bin/env bash
# ==================================================================================================
# targetSeed utility - deploy keys + helpers onto a mount root
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# ==================================================================================================

if (( BASH_VERSINFO[0] < 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] < 3) )); then
    printf 'TARGETSEED: requires Bash 5.3 or newer (found %s).\n' "${BASH_VERSION}" >&2
    return 1 2>/dev/null || exit 1
fi

_TARGETSEED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for f in "${_TARGETSEED_DIR}/ops"/*.sh; do
    [[ -f "$f" ]] || continue
    # shellcheck disable=SC1090
    source "$f"
done

targetSeed_onLoad() { return 0; }
targetSeed_onExit() { return 0; }
