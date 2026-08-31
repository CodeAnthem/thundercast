#!/usr/bin/env bash
# ==================================================================================================
# Flake utility - entry (define hooks only; sourcing does no work)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-08-31
# Description:   Context-free flake.lock / flake.nix git URL discovery
# ==================================================================================================

if (( BASH_VERSINFO[0] < 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] < 3) )); then
    printf 'FLAKE: requires Bash 5.3 or newer (found %s).\n' "${BASH_VERSION}" >&2
    return 1 2>/dev/null || exit 1
fi

if ! declare -F error >/dev/null 2>&1; then
    error() {
        printf 'FLAKE: %s\n' "$1" >&2
    }
fi

if ! declare -F err >/dev/null 2>&1; then
    err() {
        error "${FUNCNAME[1]:-flake}: $1"
    }
fi

_FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Description: Source every *.sh in a directory.
# Arguments:
# - dir: <String> Absolute directory path
_flake_source_dir() {
    local dir="$1"
    local f
    for f in "$dir"/*.sh; do
        [[ -f "$f" ]] || continue
        # shellcheck disable=SC1090
        source "$f"
    done
}

_flake_source_dir "${_FLAKE_DIR}/helpers"
# shellcheck disable=SC1091
source "${_FLAKE_DIR}/flake_list.sh"

# Description: No-op load (discovery is pure).
# Returns:
# - <Bool> 0
flake_onLoad() {
    return 0
}

# Description: No-op exit.
# Returns:
# - <Bool> 0
flake_onExit() {
    return 0
}
