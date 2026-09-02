#!/usr/bin/env bash
# ==================================================================================================
# nixos utility - store helpers + nixos-install runners (no step UI)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# ==================================================================================================

if (( BASH_VERSINFO[0] < 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] < 3) )); then
    printf 'NIXOS: requires Bash 5.3 or newer (found %s).\n' "${BASH_VERSION}" >&2
    return 1 2>/dev/null || exit 1
fi

_NIXOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_nixos_source_dir() {
    local dir="$1" f
    for f in "$dir"/*.sh; do
        [[ -f "$f" ]] || continue
        # shellcheck disable=SC1090
        source "$f"
    done
}

_nixos_source_dir "${_NIXOS_DIR}/ops"

nixos_onLoad() { return 0; }
nixos_onExit() { return 0; }
