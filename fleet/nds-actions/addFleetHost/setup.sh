#!/usr/bin/env bash
# ==================================================================================================
# NDS - Add a fleet host
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-20 | Modified: 2026-10-01
# Description:   Scaffold a host from a role and record a portable recipe
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

import_dir "${BASH_SOURCE[0]%/*}/logic" --depth 0

action_groups() {
    printf '%s\n' install flake git scaffold network boot disk encryption bundle
}

action_preview() {
    ui_h "New flake host from a role"
    ui_b "Scaffold the host directory, write a portable recipe, and push the leaf."
}

hook_access() {
    nds_access_write "$1" FLAKE_LOCATION
}

hook_ask() {
    nds_ask_if_empty "$1" FLAKE_HOST nds_ask_flakeHost
    nds_ask_if_empty "$1" SCAFFOLD_MODE
    nds_ask_if_empty "$1" SCAFFOLD_ROLE
    nds_flake_note_disko "$1"
    nds_ask_groups_if_empty "$1" network boot disk encryption bundle
}

hook_material() {
    nds_materialize "$1"
    nds_fleet_prepare "$1"
}

hook_cook() {
    nds_leaf_push "$1"
    nds_install_flake "$1"
}
