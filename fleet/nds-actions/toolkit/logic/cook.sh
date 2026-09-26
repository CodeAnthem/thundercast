#!/usr/bin/env bash
# ==================================================================================================
# toolkit - cook operator keys, the leaf, and the seed tree
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_toolkit_write_operator_pubs() {
    local _tk_leaf=$1 _tk_age_pub=$2 _tk_ssh_pub=$3
    local _tk_dir="${_tk_leaf}/.toolkit/operator/keys"
    mkdir -p "$_tk_dir" || return 1
    printf '%s\n' "$_tk_age_pub" > "${_tk_dir}/operator_age.pub"
    printf '%s\n' "$_tk_ssh_pub" > "${_tk_dir}/toolkit_ssh.pub"
}

nds_toolkit_ensure_sops() {
    local _tk_leaf=$1
    [[ -f "${_tk_leaf}/.sops.yaml" ]] && return 0
    printf '%s\n' 'creation_rules: []' > "${_tk_leaf}/.sops.yaml"
}

nds_toolkit_build_seed() {
    local _tk_seed=$1 _tk_age=$2 _tk_ssh=$3 _tk_ssh_pub=$4
    mkdir -p "${_tk_seed}/etc/sops/age" "${_tk_seed}/root/.ssh" || return 1
    cp "$_tk_age" "${_tk_seed}/etc/sops/age/operator_sops.key" || return 1
    cp "$_tk_ssh" "${_tk_seed}/root/.ssh/id_ed25519" || return 1
    cp "$_tk_ssh_pub" "${_tk_seed}/root/.ssh/id_ed25519.pub" || return 1
    chmod 600 "${_tk_seed}/etc/sops/age/operator_sops.key" "${_tk_seed}/root/.ssh/id_ed25519"
}

nds_toolkit_seed_scripts_to_target() {
    local _tk_url=${2:-https://github.com/CodeAnthem/thundercast.git}
    mkdir -p /mnt/var/lib/nds-toolkit || return 1
    git_clone "" "$_tk_url" /mnt/var/lib/nds-toolkit/src || return 1
    ln -sfn src /mnt/var/lib/nds-toolkit/current
}
