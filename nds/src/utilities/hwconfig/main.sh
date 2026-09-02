#!/usr/bin/env bash
# ==================================================================================================
# hwconfig utility - nixos-generate-config hardware-configuration.nix
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# ==================================================================================================

if (( BASH_VERSINFO[0] < 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] < 3) )); then
    printf 'HWCONFIG: requires Bash 5.3 or newer (found %s).\n' "${BASH_VERSION}" >&2
    return 1 2>/dev/null || exit 1
fi

_HWCONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for f in "${_HWCONFIG_DIR}/ops"/*.sh; do
    [[ -f "$f" ]] || continue
    # shellcheck disable=SC1090
    source "$f"
done

hwconfig_onLoad() { return 0; }
hwconfig_onExit() { return 0; }
