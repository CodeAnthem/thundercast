#!/usr/bin/env bash
# ==================================================================================================
# NDS - Leaf / action lifecycle hooks
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-28 | Modified: 2026-08-28
# Description:   Source .nds/lib then register from .nds/<action> and .nds/common
# ==================================================================================================

declare -gA NDS_HOOK_FNS=()
declare -g NDS_HOOKS_LOADED_KEY=""
declare -g NDS_HOOK_FILE_DID_REGISTER=0

# Description: Known lifecycle events (ISO install).
_nds_hook_events() {
    printf '%s\n' post_scaffold pre_install post_install
}

# Description: Event name from a hook filename (post_install.sh, post_install-age.sh).
# Arguments:
# - basename: <String> File basename
# Returns:
# - <String> event or empty
_nds_hook_event_from_filename() {
    local base="$1"
    case "$base" in
        post_scaffold.sh|post_scaffold-*.sh) printf '%s\n' post_scaffold ;;
        pre_install.sh|pre_install-*.sh) printf '%s\n' pre_install ;;
        post_install.sh|post_install-*.sh) printf '%s\n' post_install ;;
    esac
}

# Description: Event from a `# nds-hook: EVENT` line in the first 30 lines.
# Arguments:
# - path: <String> Hook script
_nds_hook_event_from_header() {
    local path="$1" line ev
    while IFS= read -r line; do
        [[ "$line" == "# nds-hook:"* ]] || continue
        ev="${line#\# nds-hook:}"
        ev="${ev#"${ev%%[![:space:]]*}"}"
        ev="${ev%%[[:space:]]*}"
        printf '%s\n' "$ev"
        return 0
    done < <(head -n 30 "$path" 2>/dev/null)
    return 1
}

# Description: Register a function for a lifecycle event.
# Arguments:
# - event:    <String> post_scaffold | pre_install | post_install
# - fn:       <String> Function name
nds_hook_register() {
    local event="$1" fn="$2" cur
    [[ -n "$event" && -n "$fn" ]] || return 1
    declare -f "$fn" >/dev/null || {
        error "nds_hook_register: ${fn} is not a function"
        return 1
    }
    cur="${NDS_HOOK_FNS[$event]:-}"
    if [[ -n "$cur" ]]; then
        NDS_HOOK_FNS[$event]="${cur}"$'\n'"${fn}"
    else
        NDS_HOOK_FNS[$event]="$fn"
    fi
    NDS_HOOK_FILE_DID_REGISTER=1
    return 0
}

# Description: Drop all registered leaf hooks (tests / reload).
nds_hook_reset() {
    NDS_HOOK_FNS=()
    NDS_HOOKS_LOADED_KEY=""
}

# Description: Source one hook file; auto-register run() when the name/header names an event.
# Arguments:
# - path:     <String> .sh path
# - lib_only: <String> 1 = functions only (no auto-register)
_nds_hook_source_file() {
    local path="$1"
    local lib_only="${2:-0}"
    local base ev header_ev id
    base="$(basename "$path")"
    [[ "$base" == *.sh ]] || return 0
    [[ "$base" == nds.sh ]] && return 0
    [[ "${base:0:1}" == "_" ]] && return 0

    NDS_HOOK_FILE_DID_REGISTER=0
    nds_import_file "$path" || return 1
    [[ "$lib_only" == "1" ]] && return 0

    ev="$(_nds_hook_event_from_filename "$base")"
    header_ev="$(_nds_hook_event_from_header "$path" || true)"
    [[ -n "$header_ev" ]] && ev="$header_ev"

    if [[ "$NDS_HOOK_FILE_DID_REGISTER" != "1" && -n "$ev" ]] && declare -f run >/dev/null; then
        local id
        id="nds_hook_auto_${ev}_${RANDOM}${RANDOM}"
        eval "$(declare -f run | awk -v n="$id" 'NR==1 { sub(/^run/, n) } { print }')"
        unset -f run 2>/dev/null || true
        nds_hook_register "$ev" "$id" || return 1
    fi
    return 0
}

# Description: Source every *.sh in a directory (non-recursive).
# Arguments:
# - dir:      <String> Directory
# - lib_only: <String> 1 = functions only
_nds_hook_source_dir() {
    local dir="$1"
    local lib_only="${2:-0}"
    local f
    [[ -d "$dir" ]] || return 0
    for f in "$dir"/*.sh; do
        [[ -f "$f" ]] || continue
        _nds_hook_source_file "$f" "$lib_only" || return 1
    done
    return 0
}

# Description: Load lib functions, then action pack + leaf registers.
# Arguments:
# - flake_root: <String> Leaf checkout
nds_hook_load() {
    local flake_root="$1"
    local action role key
    action="${NDS_CURRENT_ACTION:-${NDS_ACTION:-}}"
    [[ -n "$flake_root" ]] || return 0
    key="${action}:${flake_root}"
    [[ "$NDS_HOOKS_LOADED_KEY" == "$key" ]] && return 0
    nds_hook_reset
    NDS_HOOKS_LOADED_KEY="$key"

    _nds_hook_source_dir "${flake_root}/.nds/lib" 1 || return 1
    if [[ -n "$action" && -n "${SCRIPT_DIR:-}" ]]; then
        _nds_hook_source_dir "${SCRIPT_DIR}/actions/${action}/hooks" || return 1
    fi
    if [[ -n "$action" ]]; then
        _nds_hook_source_dir "${flake_root}/.nds/${action}" || return 1
    fi
    _nds_hook_source_dir "${flake_root}/.nds/common" || return 1

    role="$(nds_cfg_get SCAFFOLD_ROLE 2>/dev/null || true)"
    if [[ -n "$role" ]]; then
        _nds_hook_source_dir "${flake_root}/.roles/${role}/hooks" || return 1
    fi
    return 0
}

# Description: Run registered functions for one event.
# Arguments:
# - flake_root: <String> Leaf checkout
# - event:      <String> Lifecycle event
nds_hook_run() {
    local flake_root="$1"
    local event="$2"
    local fn

    nds_hook_load "$flake_root" || return 1
    export NDS_LEAF_HOOK="$event"

    while IFS= read -r fn; do
        [[ -n "$fn" ]] || continue
        "$fn" || return 1
    done < <(printf '%s\n' "${NDS_HOOK_FNS[$event]:-}")
    return 0
}
