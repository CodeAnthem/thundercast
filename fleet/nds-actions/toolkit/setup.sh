#!/usr/bin/env bash
# ==================================================================================================
# NDS - Toolkit ops VM
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-20 | Modified: 2026-09-26
# Description:   Create or restore the toolkit host and seed its keys
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

import_dir "${BASH_SOURCE[0]%/*}/logic" --depth 0
eventRegister cook.post_install _nds_toolkit_on_post_install

action_groups() {
    printf '%s\n' install toolkit flake git boot disk encryption platform
}

action_preview() {
    ui_h "Create or restore the toolkit VM"
    ui_b "Write operator keys into the leaf and seed them onto the machine."
}

action_defaults() {
    printf '%s\n' FLAKE_HOST=control-toolkit TOOLKIT_MODE=new
}

action_pins() {
    printf '%s\n' INSTALL_KIND=flake INSTALL_MODE=local
}

action_recipe() {
    local -n _R=$1
    local _tk_leaf _tk_sec _tk_seed _tk_host _tk_age _tk_ssh _tk_age_pub _tk_ssh_pub
    _tk_leaf="${ nds_session_dir work; }/leaf"
    _tk_sec="${ nds_session_dir secrets; }/toolkit"
    _tk_seed="${ nds_session_dir seed; }"
    _tk_host=${_R[FLAKE_HOST]:-control-toolkit}
    mkdir -p "$_tk_sec" "${_tk_leaf}/.nds/hosts" || return 1
    _tk_age="${_tk_sec}/operator_age.txt"
    _tk_ssh="${_tk_sec}/toolkit_ssh"
    if [[ ${_R[TOOLKIT_MODE]:-new} == restore ]]; then
        nds_toolkit_restore_from_bundle "${_R[TOOLKIT_BUNDLE]:-}" "$_tk_sec" || return 1
    fi
    if [[ ! -f "$_tk_age" ]]; then
        age-keygen -o "$_tk_age" || return 1
        chmod 600 "$_tk_age"
    fi
    if [[ ! -f "$_tk_ssh" ]]; then
        ssh-keygen -t ed25519 -N "" -f "$_tk_ssh" || return 1
        chmod 600 "$_tk_ssh"
    fi
    _tk_age_pub=$(awk -F': ' '/^# public key: / { print $2; exit }' "$_tk_age")
    _tk_ssh_pub=$(<"${_tk_ssh}.pub")
    nds_recipe_set "$1" TOOLKIT_AGE_KEY_FILE "$_tk_age"
    nds_recipe_set "$1" TOOLKIT_SSH_KEY_FILE "$_tk_ssh"
    nds_toolkit_write_operator_pubs "$_tk_leaf" "$_tk_age_pub" "$_tk_ssh_pub" || return 1
    nds_toolkit_ensure_sops "$_tk_leaf" || return 1
    nds_toolkit_build_seed "$_tk_seed" "$_tk_age" "$_tk_ssh" "${_tk_ssh}.pub" || return 1
    nds_recipe_export "$1" "${_tk_leaf}/.nds/hosts/${_tk_host}.recipe" --portable || return 1
    nds_recipe_set "$1" TARGET_SEED_DIR "$_tk_seed"
    nds_recipe_set "$1" LEAF_PUSH_DIR "$_tk_leaf"
    nds_recipe_set "$1" LEAF_PUSH_MESSAGE "nds: toolkit ${_R[TOOLKIT_MODE]:-new} host ${_tk_host}"
    declare -f nds_requireUtility >/dev/null && { nds_requireUtility sops || return 1; }
    sops_writeLeafPub "$1" "$_tk_leaf" || return 1
}
