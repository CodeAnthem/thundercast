#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Bash Version
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-22 | Modified: 2026-09-23
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
    local -n config="essentials_config"
    local major="${config[BASHVERSION_MAJOR]:-0}"
    (( major == 0 )) && return 0
    bashVersion_check "$major" "${config[BASHVERSION_MINOR]:-3}"
}
_essentials_bashVersion_init || return 1
