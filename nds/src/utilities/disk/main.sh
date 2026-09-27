#!/usr/bin/env bash
# ==================================================================================================
# disk utility - partition / disko / LUKS / mount (no step UI)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# Description:   Flexible disk prep API. The caller owns prompts and task progress.
# ==================================================================================================

if (( BASH_VERSINFO[0] < 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] < 3) )); then
    printf 'DISK: requires Bash 5.3 or newer (found %s).\n' "${BASH_VERSION}" >&2
    return 1 2>/dev/null || exit 1
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

_disk_cmd() {
    local _disk_out _disk_rc=0 _disk_msg
    _disk_out=$(mktemp)
    "$@" >"$_disk_out" 2>&1 || _disk_rc=$?
    if [[ -s "$_disk_out" ]] && declare -f nds_diagnose_append >/dev/null; then
        nds_diagnose_append "$(<"$_disk_out")"
    fi
    if [[ "$_disk_rc" -ne 0 ]]; then
        _disk_msg=$(tr '\n' ' ' <"$_disk_out")
        rm -f "$_disk_out"
        error "$* failed (${_disk_rc}): ${_disk_msg}"
        return "$_disk_rc"
    fi
    rm -f "$_disk_out"
    return 0
}

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
