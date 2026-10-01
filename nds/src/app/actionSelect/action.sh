#!/usr/bin/env bash
# ==================================================================================================
# NDS - Action selection
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-09-25
# Description:   Discover fills a store from directories. Select picks from the local store.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

declare -g NDS_CURRENT_ACTION=""

_nds_action_joined() {
    local store="$1" name line=""
    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        line="${line:+$line }${name}"
    done <<< "${ _nds_action_store_names "$store"; }"
    printf '%s\n' "$line"
}

_nds_action_hide_debug() {
    [[ ${NDS_TEST:-} == true ]] && return 0
    _nds_action_store_remove local test
    _nds_action_store_remove local uiSmoke
}

_nds_action_use() {
    local wanted="$1"
    if ! _nds_action_store_has local "$wanted"; then
        error "NDS_ACTION=${wanted} is not valid (available: ${ _nds_action_joined local; })"
        return 1
    fi
    NDS_CURRENT_ACTION="$wanted"
    export NDS_CURRENT_ACTION
}

_nds_action_load() {
    local setup
    setup="${ _nds_action_store_path local "$NDS_CURRENT_ACTION"; }"
    import_file "$setup"
}

# Preview sources setup.sh in a copy of this process. eventRegister there
# does not exist here. The parent sources the file only after accept.
_nds_action_preview_in_subshell() {
    local setup rc=0
    setup="${ _nds_action_store_path local "$NDS_CURRENT_ACTION"; }"
    (
        import_file "$setup" || exit 1
        _nds_action_ui_preview
        exit $?
    ) || rc=$?
    return "$rc"
}

_nds_action_preview_skipped() {
    if [[ -n ${NDS_IMPORT:-} || -n ${NDS_RESTORE_FILE:-} ]]; then
        return 1
    fi
    nds_skip action.preview
}

_nds_action_clear_sourced() {
    unset -f action_groups action_preview action_defaults action_pins action_recipe action_plan action_access
}

# Add setup.sh folders from one directory. Does not clear the store.
nds_action_discover() {
    local store="${1:-}" path="${2:-}"
    if [[ "$store" != local && "$store" != remote ]]; then
        error "Unknown action store: ${store}"
        return 1
    fi
    if [[ ! -d "$path" ]]; then
        error "Actions directory not found: ${path}"
        return 1
    fi
    _nds_action_collect "$store" "$path"
    _nds_action_store_validate "$store"
    return 0
}

# Pick, source, and accept the preview. Back returns to the menu unless NDS_ACTION is set.
nds_action_select() {
    local rc=0
    while true; do
        if [[ -n "${NDS_ACTION:-}" ]]; then
            _nds_action_use "$NDS_ACTION" || return 1
        elif nds_mode_is_unattended; then
            error "Unattended mode requires NDS_ACTION (available: ${ _nds_action_joined local; })"
            return 1
        elif [[ ! -t 0 ]]; then
            error "No terminal. Set NDS_ACTION (available: ${ _nds_action_joined local; })"
            return 1
        else
            _nds_action_ui_select || return $?
        fi

        if _nds_action_preview_skipped; then
            _nds_action_load || return 1
            return 0
        fi

        rc=0
        _nds_action_preview_in_subshell || rc=$?
        if [[ "$rc" -eq 0 ]]; then
            _nds_action_load || return 1
            return 0
        fi
        if [[ "$rc" -eq 2 ]]; then
            if [[ -n "${NDS_ACTION:-}" ]]; then
                error "Cannot go back — NDS_ACTION is set to ${NDS_ACTION}"
                return 1
            fi
            _nds_action_clear_sourced
            NDS_CURRENT_ACTION=""
            continue
        fi
        return "$rc"
    done
}
