#!/usr/bin/env bash
# ==================================================================================================
# NDS - Action UI
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-24 | Modified: 2026-09-25
# Description:   Menu and preview for the local store. Select calls these only on a terminal.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_nds_action_ui_select() {
    local -a _nds_action_options=()
    local name description rc=0
    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        description="${ _nds_action_store_description local "$name"; }"
        _nds_action_options+=("${name}|${name}|${description}")
    done <<< "${ _nds_action_store_names local; }"
    tty_guardEnable
    ui_section "Action"
    ui_b "Pick what this run should do. The line under each name says what that action covers."
    prompt --type select --options _nds_action_options --back "Choose an action" || rc=$?
    if [[ "$rc" -eq 2 || "$rc" -eq 3 ]]; then
        info "Action select aborted"
        return 130
    fi
    [[ "$rc" -eq 0 ]] || return "$rc"
    NDS_CURRENT_ACTION="$UI_PROMPT_RESULT"
    export NDS_CURRENT_ACTION
    return 0
}

_nds_action_ui_preview() {
    local rc=0
    ui_section "Install preview"
    action_preview
    ui_b "Press Y to continue, B to go back to the action menu."
    prompt --type confirm --back --message "Proceed with this action?" || rc=$?
    case "$rc" in
        0)
            [[ "$UI_PROMPT_RESULT" == y ]] && return 0
            info "Action preview declined"
            return 1
            ;;
        2) return 2 ;;
        *)
            info "Action preview aborted"
            return 1
            ;;
    esac
}
