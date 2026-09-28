#!/usr/bin/env bash
# ==================================================================================================
# addFleetHost - copy a role template into the leaf host directory
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_fleet_scaffold_host() {
    local -n _sc_R=$1
    local _sc_leaf=$2
    local _sc_host=${_sc_R[FLAKE_HOST]:-} _sc_role=${_sc_R[SCAFFOLD_ROLE]:-}
    local _sc_rel=${_sc_R[FLAKE_HOST_DIR]:-hosts/x86_64-linux}
    local _sc_flake=${_sc_R[FLAKE_LOCAL_PATH]:-}
    local _sc_src="${_sc_flake}/.roles/${_sc_role}"
    local _sc_dest="${_sc_leaf}/${_sc_rel}/${_sc_host}"
    local _sc_tmpl="" _sc_date
    mkdir -p "$_sc_dest" "${_sc_leaf}/.nds/hosts" || return 1
    if [[ -d "$_sc_src" ]]; then
        cp -a "${_sc_src}/." "$_sc_dest/" || return 1
    fi
    _sc_tmpl="${ scriptInfo_get_dir; }/actions/installFlake/templates"
    [[ -d "$_sc_tmpl" ]] || return 0
    _sc_date=$(date -u +%Y-%m-%d)
    if [[ ! -f "${_sc_dest}/opts.nix" && -f "${_sc_tmpl}/host-opts.nix.tmpl" ]]; then
        sed "s/__ROLE__/${_sc_role}/g" "${_sc_tmpl}/host-opts.nix.tmpl" > "${_sc_dest}/opts.nix" || return 1
    fi
    if [[ -f "${_sc_tmpl}/host-generated.nix.tmpl" ]]; then
        sed -e "s/__HOSTNAME__/${_sc_host}/g" -e "s/__DATE__/${_sc_date}/g" \
            "${_sc_tmpl}/host-generated.nix.tmpl" > "${_sc_dest}/nds_generated.nix" || return 1
    fi
    if [[ ${_sc_R[NETWORK_METHOD]:-dhcp} == static && -f "${_sc_tmpl}/host-configuration.nix.tmpl" ]]; then
        sed -e "s/__HOSTNAME__/${_sc_host}/g" -e "s/__STATE_VERSION__/24.11/g" \
            "${_sc_tmpl}/host-configuration.nix.tmpl" > "${_sc_dest}/configuration.nix" || return 1
    elif [[ -f "${_sc_tmpl}/host-configuration-dhcp.nix.tmpl" ]]; then
        sed -e "s/__HOSTNAME__/${_sc_host}/g" -e "s/__STATE_VERSION__/24.11/g" \
            "${_sc_tmpl}/host-configuration-dhcp.nix.tmpl" > "${_sc_dest}/configuration.nix" || return 1
    fi
}
