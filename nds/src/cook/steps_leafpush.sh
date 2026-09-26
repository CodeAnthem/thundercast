#!/usr/bin/env bash
# ==================================================================================================
# NDS - Cook leaf push
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

step_leafPush() {
    local -n _R=$1
    local _leaf_dir=${_R[LEAF_PUSH_DIR]:-}
    [[ -n "$_leaf_dir" ]] || return 0
    git_commitAll "$_leaf_dir" "${_R[LEAF_PUSH_MESSAGE]:-}" hosts .nds .toolkit .sops.yaml || return 1
    git_push "${_R[GIT_KEYS_DIR]:-}" "$_leaf_dir" || return 1
}
