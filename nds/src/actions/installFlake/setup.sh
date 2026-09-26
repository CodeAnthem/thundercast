#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install from a flake
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-09-26
# Description:   Install NixOS from a local or remote flake
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

action_groups() {
    printf '%s\n' install flake git boot disk encryption
}

action_preview() {
    ui_h "Install NixOS from a flake"
    ui_b "Choose the flake, the host, git access, boot, disk, and encryption."
}

action_pins() {
    printf '%s\n' INSTALL_KIND=flake
}
