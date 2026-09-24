#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Trap Bridge
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-17 | Modified: 2026-09-24
# Description:   Turns Bash traps into events on the event bus.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_essentials_trapBridge_init() {
    _essentials_init_isDone trapBridge && return 0

    local -n config="essentials_config"

    # shellcheck source=./trapBridge_dispatch.sh
    _loadEssential "trapBridge/trapBridge_dispatch.sh"

    if [[ "${config[TRAP_PRESETS]:-false}" == true ]]; then
        # shellcheck source=./trapBridge_presets.sh
        _loadEssential "trapBridge/trapBridge_presets.sh"
    fi

    _essentials_init_mark trapBridge
}
_essentials_trapBridge_init || return 1
