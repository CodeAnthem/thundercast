#!/usr/bin/env bash
# ==================================================================================================
# NDS - Remote catalog action
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-10-01
# Description:   Clone a catalog and cook the named action after its preview
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

action_groups() {
    printf '%s\n' install catalog
}

action_preview() {
    ui_h "Run an action from a catalog"
    ui_b "Clone the catalog, accept that action, then cook its recipe."
}

hook_access() {
    nds_access_read "$1" CATALOG_URL
}

hook_ask() {
    nds_ask_if_empty "$1" CATALOG_ACTION nds_ask_catalogAction
    nds_catalog_load "$1"
}
