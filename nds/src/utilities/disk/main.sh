#!/usr/bin/env bash
# ==================================================================================================
# disk utility - partition / disko / LUKS / mount (no step UI)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# Description:   Flexible disk prep API. Shot caller owns prompts and nds_step_*.
# ==================================================================================================

if (( BASH_VERSINFO[0] < 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] < 3) )); then
    printf 'DISK: requires Bash 5.3 or newer (found %s).\n' "${BASH_VERSION}" >&2
    return 1 2>/dev/null || exit 1
fi

if ! declare -F error >/dev/null 2>&1; then
    error() { printf 'DISK: %s\n' "$1" >&2; }
fi
if ! declare -F err >/dev/null 2>&1; then
    err() { error "${FUNCNAME[1]:-disk}: $1"; }
fi
if ! declare -F log >/dev/null 2>&1; then
    log() { printf 'DISK: %s\n' "$1" >&2; }
fi
if ! declare -F warn >/dev/null 2>&1; then
    warn() { printf 'DISK: warn: %s\n' "$1" >&2; }
fi

_DISK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_disk_source_dir() {
    local dir="$1" f
    for f in "$dir"/*.sh; do
        [[ -f "$f" ]] || continue
        # shellcheck disable=SC1090
        source "$f"
    done
}

_disk_source_dir "${_DISK_DIR}/helpers"
_disk_source_dir "${_DISK_DIR}/ops"

disk_onLoad() { return 0; }
disk_onExit() { return 0; }
