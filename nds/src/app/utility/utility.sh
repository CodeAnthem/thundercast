#!/usr/bin/env bash
# ==================================================================================================
# NDS - Utility loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-09-25
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

declare -gA _NDS_UTILITIES_LOADED=()
declare -ga _NDS_UTILITY_ONEXIT=()
declare -ga _NDS_UTILITY_ROOTS=()

nds_utility_addRoot() {
    local _nds_util_root=$1
    [[ -d "$_nds_util_root" ]] || {
        error "nds_utility_addRoot: not a directory: ${_nds_util_root}"
        return 1
    }
    _NDS_UTILITY_ROOTS+=("$_nds_util_root")
}

# Best-effort. One failure must not skip the remaining utilities.
_nds_utility_onExit() {
    local fn
    for fn in "${_NDS_UTILITY_ONEXIT[@]+"${_NDS_UTILITY_ONEXIT[@]}"}"; do
        [[ -n "$fn" ]] || continue
        declare -f "$fn" >/dev/null || continue
        "$fn" || true
    done
    return 0
}

eventCreate utility.load
eventRegister exit _nds_utility_onExit

# Source utilities/<name>/main.sh once. A <name>_onLoad joins utility.load.
# A <name>_onExit joins the exit hook above. Neither runs here.
nds_requireUtility() {
    local name="${1:-}"
    local src_dir main on_load on_exit _nds_util_root

    if [[ ! "$name" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]]; then
        error "nds_requireUtility: invalid name: ${name}"
        return 1
    fi
    if [[ -n "${_NDS_UTILITIES_LOADED[$name]:-}" ]]; then
        return 0
    fi

    src_dir="${ scriptInfo_get_dir; }"
    main=""
    for _nds_util_root in "${src_dir}/utilities" "${_NDS_UTILITY_ROOTS[@]+"${_NDS_UTILITY_ROOTS[@]}"}"; do
        if [[ -f "${_nds_util_root}/${name}/main.sh" ]]; then
            main="${_nds_util_root}/${name}/main.sh"
            break
        fi
    done
    if [[ -z "$main" ]]; then
        error "nds_requireUtility: not found: ${name}"
        return 1
    fi
    import_file "$main" || return 1

    on_load="${name}_onLoad"
    on_exit="${name}_onExit"
    if declare -f "$on_load" >/dev/null; then
        eventRegister utility.load "$on_load" || return 1
    fi
    if declare -f "$on_exit" >/dev/null; then
        _NDS_UTILITY_ONEXIT+=("$on_exit")
    fi

    _NDS_UTILITIES_LOADED["$name"]=1
    return 0
}
