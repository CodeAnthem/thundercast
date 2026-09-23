#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Trap Bridge
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-17 | Modified: 2026-09-17
# ==================================================================================================
#
# Translates bash traps into eventBus events. Does not alias `trap`.
#
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_essentials_trapBridge_init() {
    [[ "${__TRAP_INITIALIZED:-false}" == true ]] && return 0

    local -n config="essentials_config"

    # shellcheck source=./trapBridge_dispatch.sh
    loadModule "trapBridge/trapBridge_dispatch.sh"

    if [[ "${config[TRAP_PRESETS]:-false}" == true ]]; then
        # shellcheck source=./trapBridge_presets.sh
        loadModule "trapBridge/trapBridge_presets.sh"
    fi

    declare -g __TRAP_INITIALIZED=true
}
_essentials_trapBridge_init || return 1
