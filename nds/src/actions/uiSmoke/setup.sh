#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI smoke action
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-07 | Modified: 2026-10-01
# Description:   Interactive screen walk, hidden unless NDS_TEST is set
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

action_groups() {
    :
}

action_preview() {
    ui_h "UI smoke"
    ui_b "Walk the interactive screens. Nothing is installed."
}

hook_ask() {
    local _ui_name=$1 _ui_type _ui_key
    declare -f nds_mode_is_unattended >/dev/null && nds_mode_is_unattended && return 0
    nds_schema_group uismoke "UI smoke" 2>/dev/null || true
    nds_schema_enable uismoke
    for _ui_type in string bool int port choice path file dir disk ip hostname username url timezone locale keyboard country mask secret; do
        _ui_key="UI_${_ui_type^^}"
        if ! nds_schema_hasKey "$_ui_key"; then
            if [[ "$_ui_type" == choice ]]; then
                nds_schema_field uismoke "$_ui_key" choice --choices 'a|b' --label "$_ui_type"
            else
                nds_schema_field uismoke "$_ui_key" "$_ui_type" --label "$_ui_type"
            fi
        fi
        "_nds_ask_${_ui_type}" "$_ui_name" "$_ui_key"
    done
}
