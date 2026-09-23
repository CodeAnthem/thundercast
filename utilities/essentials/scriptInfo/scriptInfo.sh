#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Script Info
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2026-09-17
# ==================================================================================================
#
# Script directory, name, and version. Loads before logger.
#
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_essentials_scriptInfo_init() {
    [[ "${__SCRIPTINFO_INITIALIZED:-false}" == true ]] && return 0

    local -n config="essentials_config"
    declare -gA __ESSENTIALS_SCRIPTINFO=(
        [script_dir]="${config[SCRIPTINFO_DIR]:-}"
        [script_name]="${config[SCRIPTINFO_NAME]:-}"
        [script_version]="${config[SCRIPTINFO_VERSION]:-}"
    )
    [[ -n "${__ESSENTIALS_SCRIPTINFO[script_dir]}" ]] || { echo "[ERROR] - [ScriptInfo] - SCRIPTINFO_DIR is required" >&2; exit 1; }
    [[ -n "${__ESSENTIALS_SCRIPTINFO[script_name]}" ]] || { echo "[ERROR] - [ScriptInfo] - SCRIPTINFO_NAME is required" >&2; exit 1; }
    [[ -n "${__ESSENTIALS_SCRIPTINFO[script_version]}" ]] || { echo "[ERROR] - [ScriptInfo] - SCRIPTINFO_VERSION is required" >&2; exit 1; }
    declare -g __SCRIPTINFO_INITIALIZED=true
}
_essentials_scriptInfo_init || return 1

scriptInfo_get() {
    local key
    for key in "${!__ESSENTIALS_SCRIPTINFO[@]}"; do
        echo "${key}: ${__ESSENTIALS_SCRIPTINFO[${key}]}"
    done
}

scriptInfo_get_name() { echo "${__ESSENTIALS_SCRIPTINFO[script_name]}"; }
scriptInfo_get_version() { echo "${__ESSENTIALS_SCRIPTINFO[script_version]}"; }
scriptInfo_get_dir() { echo "${__ESSENTIALS_SCRIPTINFO[script_dir]}"; }
