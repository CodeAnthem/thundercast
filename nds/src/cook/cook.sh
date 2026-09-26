#!/usr/bin/env bash
# ==================================================================================================
# NDS - Birth a machine from a sealed recipe
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Load, validate, preflight, then one fixed plan. No TTY.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

declare -g _NDS_TARGET_ROOT="${_NDS_TARGET_ROOT:-/mnt}"

eventCreate cook.pre_disk
eventCreate cook.post_disk
eventCreate cook.pre_install
eventCreate cook.post_install
eventCreate cook.done

_cook_step() {
    local _cook_label=$1
    shift
    taskStart "$_cook_label"
    if "$@"; then
        taskOk
        return 0
    fi
    taskFail
    nds_cook_diag_step_failure "$_cook_label" || true
    return 1
}

_nds_cook_unlock() {
    local _cook_key
    local -a _cook_locked=()
    for _cook_key in "${!_NDS_SCHEMA_ATTR[@]}"; do
        [[ "$_cook_key" == *'|locked' ]] || continue
        _cook_locked+=("$_cook_key")
    done
    for _cook_key in "${_cook_locked[@]+"${_cook_locked[@]}"}"; do
        unset "_NDS_SCHEMA_ATTR[$_cook_key]"
    done
}

nds_cook() {
    local -A R=()
    local _cook_file=$1 _cook_kind _cook_mode _cook_n=0
    _nds_cook_unlock
    nds_schema_enableAll || return 1
    nds_recipe_loadFile R "$_cook_file" || return 1
    nds_recipe_validate R || _cook_n=$?
    if (( _cook_n != 0 )); then
        return 1
    fi
    _NDS_REALIZE_AA=R
    nds_cook_preflight R || return 1
    _cook_kind=${R[INSTALL_KIND]:-}
    _cook_mode=${R[INSTALL_MODE]:-local}
    case "${_cook_kind}/${_cook_mode}" in
        classic/local|classic/remote) nds_cook_plan_classic R || return 1 ;;
        flake/local) nds_cook_plan_flake_local R || return 1 ;;
        flake/remote) nds_cook_plan_flake_remote R || return 1 ;;
        *)
            error "INSTALL_KIND: unsupported ${_cook_kind}/${_cook_mode}"
            return 1
            ;;
    esac
}
