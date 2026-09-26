#!/usr/bin/env bash
# ==================================================================================================
# addFleetHost - copy a role template into the leaf host directory
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_fleet_scaffold_host() {
    local _sc_flake=$1 _sc_role=$2 _sc_host=$3 _sc_leaf=$4
    local _sc_src="${_sc_flake}/.roles/${_sc_role}"
    local _sc_dest="${_sc_leaf}/hosts/x86_64-linux/${_sc_host}"
    mkdir -p "$_sc_dest" "${_sc_leaf}/.nds/hosts" || return 1
    if [[ -d "$_sc_src" ]]; then
        cp -a "${_sc_src}/." "$_sc_dest/" || return 1
    fi
}
