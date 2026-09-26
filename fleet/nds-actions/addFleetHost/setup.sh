#!/usr/bin/env bash
# ==================================================================================================
# NDS - Add a fleet host
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-20 | Modified: 2026-09-26
# Description:   Scaffold a host from a role and record a portable recipe
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

import_dir "${BASH_SOURCE[0]%/*}/logic" --depth 0

action_groups() {
    printf '%s\n' install flake git scaffold network boot disk encryption
}

action_preview() {
    ui_h "New flake host from a role"
    ui_b "Scaffold the host directory, write a portable recipe, and push the leaf."
}

action_pins() {
    printf '%s\n' INSTALL_KIND=flake
}

action_recipe() {
    local -n _R=$1
    local _fh_leaf _fh_host _fh_role _fh_msg
    _fh_leaf="${ nds_session_dir work; }/leaf"
    _fh_host=${_R[FLAKE_HOST]:-}
    _fh_role=${_R[SCAFFOLD_ROLE]:-}
    [[ -n "$_fh_host" ]] || { error "FLAKE_HOST: required"; return 1; }
    if [[ ${_R[SCAFFOLD_MODE]:-new} == new ]]; then
        nds_fleet_scaffold_host "$1" "$_fh_leaf" || return 1
    else
        mkdir -p "${_fh_leaf}/.nds/hosts" || return 1
    fi
    nds_recipe_export "$1" "${_fh_leaf}/.nds/hosts/${_fh_host}.recipe" --portable || return 1
    _fh_msg="nds: ${_R[SCAFFOLD_MODE]:-new} host ${_fh_host}"
    [[ -n "$_fh_role" ]] && _fh_msg="${_fh_msg} (role ${_fh_role})"
    nds_recipe_set "$1" LEAF_PUSH_DIR "$_fh_leaf"
    nds_recipe_set "$1" LEAF_PUSH_MESSAGE "$_fh_msg"
    declare -f nds_requireUtility >/dev/null && { nds_requireUtility sops || return 1; }
    sops_writeLeafPub "$1" "$_fh_leaf" || return 1
}
