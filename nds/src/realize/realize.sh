#!/usr/bin/env bash
# ==================================================================================================
# NDS - Birth a machine from a sealed recipe
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Load, validate, preflight, then one fixed plan. No TTY.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

eventCreate realize.pre_disk
eventCreate realize.post_disk
eventCreate realize.pre_install
eventCreate realize.post_install
eventCreate realize.done

_realize_step() {
    local _realize_label=$1
    shift
    taskStart "$_realize_label"
    if "$@"; then
        taskOk
        return 0
    fi
    taskFail
    return 1
}

nds_realize() {
    local -A R=()
    local _realize_file=$1 _realize_kind _realize_mode _realize_n=0
    nds_schema_enableAll || return 1
    nds_recipe_loadFile R "$_realize_file" || return 1
    nds_recipe_validate R || _realize_n=$?
    if (( _realize_n != 0 )); then
        return 1
    fi
    nds_realize_preflight R || return 1
    _realize_kind=${R[INSTALL_KIND]:-}
    _realize_mode=${R[INSTALL_MODE]:-local}
    case "${_realize_kind}/${_realize_mode}" in
        classic/local|classic/remote) nds_realize_plan_classic R || return 1 ;;
        flake/local) nds_realize_plan_flake_local R || return 1 ;;
        flake/remote) nds_realize_plan_flake_remote R || return 1 ;;
        *)
            error "INSTALL_KIND: unsupported ${_realize_kind}/${_realize_mode}"
            return 1
            ;;
    esac
}
