#!/usr/bin/env bash
# ==================================================================================================
# NDS - Action handler UI: preview
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-08-15
# ==================================================================================================

declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_ACTION_PREVIEW_SKIP

# Description: Render a comma-separated list of action items as indented UI lines.
# Arguments:
# - items: <String> Comma-separated item list
nds_app_actionHandler_ui_listItems() {
    local items="$1"
    local item
    IFS=',' read -ra _items <<< "$items"
    for item in "${_items[@]}"; do
        item="${item#"${item%%[![:space:]]*}"}"
        item="${item%"${item##*[![:space:]]}"}"
        nds_ui_i "$item"
    done
}

# Description: Run action_preview unless skipped / unattended; ask proceed/back.
# Returns:
# - 0 proceed or skipped; NDS_ACTION_BACK back; 130 abort
nds_app_actionHandler_ui_runPreview() {
    declare -f action_preview &>/dev/null || { error "action_preview() not found"; return 1; }

    if nds_skip_menu NDS_ACTION_PREVIEW_SKIP; then
        nds_log_from_env "Preview skipped"
        return 0
    fi

    nds_mode_resolve || true
    if declare -f nds_mode_is_unattended &>/dev/null && nds_mode_is_unattended; then
        nds_log_from_env "Preview skipped"
        return 0
    fi

    nds_ui_section_header "Install preview"
    action_preview
    nds_ui_b "Press Y to continue, B to go back to the action menu."
    nds_ui_b ""
    nds_ask_user_continue "Proceed with this action?"
    local prc=$?
    case "$prc" in
        0) return 0 ;;
        2) return "$NDS_ACTION_BACK" ;;
        *) return 130 ;;
    esac
}
