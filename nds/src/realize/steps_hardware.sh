#!/usr/bin/env bash
# ==================================================================================================
# NDS - Realize hardware artefacts
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Always overwrite the hardware file at the destination.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

step_hardware() {
    local -n _R=$1
    local _hw_dest=$2
    local _hw_place=${_R[FLAKE_HARDWARE_PLACEMENT]:-host-dir}
    [[ "$_hw_place" == skip ]] && return 0
    hwconfig_write "$_hw_dest"
}
