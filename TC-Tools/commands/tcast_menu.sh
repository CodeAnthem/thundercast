#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast host CLI — top-level menu
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-08-31
# ==================================================================================================

tcast_cmd_menu() {
    if ! tcast_ui_menu "tcast — ThunderCast host CLI" \
        "status" \
        "switch" \
        "switch --config" \
        "switch --force" \
        "restore" \
        "clean" \
        "clean --config" \
        "quit"
    then
        return 0
    fi
    case "$REPLY" in
        status) tcast_env_init; tcast_cmd_status ;;
        switch) tcast_cmd_switch ;;
        "switch --config") tcast_cmd_switch --config ;;
        "switch --force") tcast_cmd_switch --force ;;
        restore) tcast_cmd_restore ;;
        clean) tcast_cmd_clean ;;
        "clean --config") tcast_cmd_clean --config ;;
        quit) return 0 ;;
    esac
}
