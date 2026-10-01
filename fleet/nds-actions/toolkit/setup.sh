#!/usr/bin/env bash
# ==================================================================================================
# NDS - Toolkit ops VM
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-20 | Modified: 2026-10-01
# Description:   Create or restore the toolkit host and seed its keys
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

import_dir "${BASH_SOURCE[0]%/*}/logic" --depth 0

action_groups() {
    printf '%s\n' install toolkit flake git network access boot disk encryption platform
}

action_preview() {
    ui_h "Create or restore the toolkit VM"
    ui_b "Write operator keys into the leaf and seed them onto the machine."
}

hook_access() {
    nds_access_read "$1" FLAKE_LOCATION
}

hook_ask() {
    nds_pin "$1" INSTALL_MODE local
    nds_default "$1" FLAKE_HOST control-toolkit
    nds_default "$1" TOOLKIT_MODE new
    nds_ask_if_empty "$1" TOOLKIT_MODE
    nds_ask_if_empty "$1" FLAKE_HOST nds_ask_flakeHost
    nds_ask_if_empty "$1" TOOLKIT_CLONE_URL
    nds_flake_note_disko "$1"
    nds_ask_groups_if_empty "$1" network access boot disk encryption platform
}

hook_material() {
    nds_materialize "$1"
    nds_toolkit_prepare "$1"
}

hook_cook() {
    nds_leaf_push "$1"
    nds_install_flake "$1"
    nds_toolkit_clone_scripts "$1"
}
