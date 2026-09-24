#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Bash Version
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-22 | Modified: 2026-09-24
# Description:   Checks the running Bash against the configured minimum major and minor.
# ==================================================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

bashVersion_check() {
    local major="$1"
    local minor="$2"
    if (( BASH_VERSINFO[0] > major || (BASH_VERSINFO[0] == major && BASH_VERSINFO[1] >= minor) )); then
        return 0
    fi
    printf '[ERROR] - [BashVersion] - requires Bash %s.%s or newer (found %s).\n' "$major" "$minor" "${BASH_VERSION}" >&2
    return 1
}

_essentials_bashVersion_init() {
    _essentials_init_isDone bashVersion && return 0
    local -n config="essentials_config"
    local major="${config[BASHVERSION_MAJOR]:-0}"
    if (( major == 0 )); then
        _essentials_init_mark bashVersion
        return 0
    fi
    bashVersion_check "$major" "${config[BASHVERSION_MINOR]:-3}" || return 1
    _essentials_init_mark bashVersion
}
_essentials_bashVersion_init || return 1
