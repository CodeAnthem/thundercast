#!/usr/bin/env bash
# ==================================================================================================
# toolkit - cook operator keys, the leaf, and the seed tree
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_toolkit_restore_from_bundle() {
    local _tk_bundle=$1 _tk_dest=$2 _tk_tmp
    [[ -n "$_tk_bundle" ]] || { error "TOOLKIT_BUNDLE: required"; return 1; }
    mkdir -p "$_tk_dest" || return 1
    if [[ -d "$_tk_bundle" ]]; then
        if [[ -d "${_tk_bundle}/secrets/toolkit" ]]; then
            cp -a "${_tk_bundle}/secrets/toolkit/." "$_tk_dest/" || return 1
        else
            cp -a "${_tk_bundle}/." "$_tk_dest/" || return 1
        fi
        return 0
    fi
    [[ -f "$_tk_bundle" ]] || { error "TOOLKIT_BUNDLE: not found"; return 1; }
    _tk_tmp=$(mktemp -d)
    if [[ "$_tk_bundle" == *.tar.gz ]]; then
        tar -xzf "$_tk_bundle" -C "$_tk_tmp" || return 1
    else
        unzip -q "$_tk_bundle" -d "$_tk_tmp" || return 1
    fi
    if [[ -d "${_tk_tmp}/secrets/toolkit" ]]; then
        cp -a "${_tk_tmp}/secrets/toolkit/." "$_tk_dest/" || return 1
    else
        cp -a "${_tk_tmp}/." "$_tk_dest/" || return 1
    fi
    rm -rf "$_tk_tmp"
}

nds_toolkit_write_operator_pubs() {
    local _tk_leaf=$1 _tk_age_pub=$2 _tk_ssh_pub=$3
    local _tk_dir="${_tk_leaf}/.toolkit/operator/keys"
    mkdir -p "$_tk_dir" || return 1
    printf '%s\n' "$_tk_age_pub" > "${_tk_dir}/age.pub"
    printf '%s\n' "$_tk_ssh_pub" > "${_tk_dir}/ssh.pub"
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
    local _tk_mnt=$1 _tk_url=$2 _tk_dest="${_tk_mnt}/var/lib/nds-toolkit"
    mkdir -p "$_tk_dest" || return 1
    git_clone "" "$_tk_url" "${_tk_dest}/src" || return 1
    ln -sfn src/fleet/toolkit "${_tk_dest}/current"
    if [[ -d "${_tk_dest}/current" ]]; then
        find "${_tk_dest}/current" -type f -name '*.sh' -exec chmod +x {} +
    fi
}

_nds_toolkit_on_post_install() {
    nds_toolkit_seed_scripts_to_target /mnt "https://github.com/CodeAnthem/thundercast.git"
}
