#!/usr/bin/env bash
# ==================================================================================================
# NDS - Cook hardware artefacts
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-29
# Description:   Always overwrite. One function per artefact.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_step_hardware_write() {
    local _hw_dest=$1 _hw_artifact=$2
    mkdir -p "$(dirname "$_hw_dest")" || return 1
    if [[ "$_hw_artifact" == facter.json ]]; then
        facter_write "$_hw_dest" || return 1
        facter_sanitize "$_hw_dest" || return 1
    else
        hwconfig_generate "$_hw_dest" "$_NDS_TARGET_ROOT" || return 1
    fi
    chmod 600 "$_hw_dest" || return 1
}

step_hardware_nix() {
    local _hw_dest=$1 _hw_cfg=$2
    debug "Writing hardware-configuration.nix with nixos-generate-config"
    mkdir -p "$_hw_cfg" || return 1
    _step_hardware_write "$_hw_dest" hardware-configuration.nix || return 1
    cp "$_hw_dest" "${_hw_cfg}/hardware-configuration.nix" || return 1
}

step_hardware_facter() {
    local _hw_dest=$1 _hw_cfg=$2
    debug "Writing facter.json with nixos-facter"
    mkdir -p "$_hw_cfg" || return 1
    _step_hardware_write "$_hw_dest" facter.json || return 1
    cp "$_hw_dest" "${_hw_cfg}/facter.json" || return 1
}
