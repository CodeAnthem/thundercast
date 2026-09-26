#!/usr/bin/env bash
# ==================================================================================================
# targetSeed - copy a file tree and git keys onto a mount root
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

targetSeed_copy() {
    local _ts_src=$1 _ts_mnt=$2
    [[ -d "$_ts_src" ]] || return 1
    mkdir -p "$_ts_mnt" || return 1
    cp -a "${_ts_src}/." "$_ts_mnt/"
}

targetSeed_gitKeys() {
    local _ts_keys=$1 _ts_mnt=$2
    local _ts_dest="${_ts_mnt}/root/.ssh/nds"
    local _ts_cfg="${_ts_mnt}/root/.ssh/config"
    [[ -d "$_ts_keys" ]] || return 1
    mkdir -p "$_ts_dest" "${_ts_mnt}/root/.ssh" || return 1
    chmod 700 "${_ts_mnt}/root/.ssh" "$_ts_dest" || return 1
    cp -a "${_ts_keys}/." "$_ts_dest/" || return 1
    if [[ ! -f "$_ts_cfg" ]] || ! grep -q 'nds/config' "$_ts_cfg"; then
        printf '%s\n' 'Include nds/config' >> "$_ts_cfg"
    fi
    chmod 600 "$_ts_cfg" || return 1
}
