#!/usr/bin/env bash
# ==================================================================================================
# NDS - Realize flake staging
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

flake_copyTree() {
    local _flake_src=$1 _flake_dest=$2
    mkdir -p "$_flake_dest" || return 1
    cp -a "${_flake_src}/." "$_flake_dest/"
}

step_stageFlake() {
    local -n _R=$1
    local _flake_dest=$2
    if [[ -n ${_R[FLAKE_REPO_URL]:-} ]]; then
        git_clone "${_R[GIT_KEYS_DIR]:-}" "${_R[FLAKE_REPO_URL]}" "$_flake_dest" --depth 1
        return
    fi
    flake_copyTree "${_R[FLAKE_LOCAL_PATH]}" "$_flake_dest"
}
