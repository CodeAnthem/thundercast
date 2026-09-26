#!/usr/bin/env bash
# ==================================================================================================
# NDS - Cook seed copy
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

step_seed() {
    local -n _R=$1
    [[ -n ${_R[TARGET_SEED_DIR]:-} ]] || return 0
    targetSeed_copy "${_R[TARGET_SEED_DIR]}" "$_NDS_TARGET_ROOT"
}

step_seedGit() {
    local -n _R=$1
    [[ ${_R[GIT_PERSIST_ACCESS]:-} == true ]] || return 0
    [[ -n ${_R[GIT_KEYS_DIR]:-} ]] || return 0
    targetSeed_gitKeys "${_R[GIT_KEYS_DIR]}" "$_NDS_TARGET_ROOT"
}

step_seedRemoteArgs() {
    local -n _R=$1
    if [[ -n ${_R[TARGET_SEED_DIR]:-} ]]; then
        printf '%s\n' --extra-files "${_R[TARGET_SEED_DIR]}"
    fi
}
