#!/usr/bin/env bash
# ==================================================================================================
# NDS - Classic install action
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-09-26
# Description:   Install NixOS from a generated configuration
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

action_groups() {
    printf '%s\n' install region network access boot disk encryption platform
}

action_preview() {
    ui_h "Classic NixOS installation"
    ui_b "Configure region, network, access, boot, disk, and encryption."
    ui_b "NDS then writes the configuration and installs NixOS."
}

action_pins() {
    printf '%s\n' INSTALL_KIND=classic
}
