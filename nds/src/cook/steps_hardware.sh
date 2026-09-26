#!/usr/bin/env bash
# ==================================================================================================
# NDS - Cook hardware artefacts
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Always overwrite. Flake writes facter; classic writes hardware-configuration.nix.
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

step_hardware() {
    local -n _R=$1
    local _hw_dir=$2
    local _hw_kind=${_R[INSTALL_KIND]:-classic}
    local _hw_place=${_R[FLAKE_HARDWARE_PLACEMENT]:-host-dir}
    local _hw_artifact _hw_dest _hw_cfg
    [[ "$_hw_kind" == flake && "$_hw_place" == skip ]] && return 0
    _hw_artifact=${ hwconfig_artifactName "$_hw_kind"; } || return 1
    _hw_cfg=${ nds_session_dir config; }
    mkdir -p "$_hw_cfg" || return 1
    if [[ "$_hw_kind" != flake ]]; then
        _hw_dest="${_NDS_TARGET_ROOT}/etc/nixos/${_hw_artifact}"
    elif [[ "$_hw_place" == etc-nixos ]]; then
        _hw_dest="${_NDS_TARGET_ROOT}/etc/nixos/${_hw_artifact}"
    else
        _hw_dest="${_hw_dir}/${_hw_artifact}"
    fi
    _step_hardware_write "$_hw_dest" "$_hw_artifact" || return 1
    cp "$_hw_dest" "${_hw_cfg}/$(basename "$_hw_dest")" || return 1
}
