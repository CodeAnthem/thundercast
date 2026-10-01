#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install from a flake
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-10-01
# Description:   Install NixOS from a local or remote flake
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

action_groups() {
    printf '%s\n' install flake git network access boot disk encryption
}

action_preview() {
    ui_h "Install NixOS from a flake"
    ui_b "Choose the flake, the host, git access, boot, disk, and encryption."
}

hook_access() {
    nds_access_read "$1" FLAKE_LOCATION
}

hook_ask() {
    nds_ask_if_empty "$1" FLAKE_HOST nds_ask_flakeHost
    nds_ask_if_empty "$1" INSTALL_MODE
    if [[ $(nds_recipe_get "$1" INSTALL_MODE) == remote ]]; then
        nds_ask_if_empty "$1" REMOTE_TARGET_IP
        return 0
    fi
    nds_flake_note_disko "$1"
    nds_ask_groups_if_empty "$1" network access boot disk encryption
}

hook_material() {
    nds_materialize "$1"
}

hook_cook() {
    nds_install_flake "$1"
}
