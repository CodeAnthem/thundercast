#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Trap Bridge - Presets
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-17 | Modified: 2026-09-24
# Description:   EXIT presets when TRAP_PRESETS is true: exit always, exitError on a logger error or non-zero status, exitClean otherwise.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_essentials_trapBridge_onPresetExit() {
    local code="${1:-0}"
    eventRun exit "$code" || true
    if logger_hasError || [[ "$code" -ne 0 ]]; then
        eventRun exitError "$code" || true
        return 0
    fi
    eventRun exitClean "$code" || true
}

_essentials_trapBridge_presets_init() {
    eventCreate exit
    eventCreate exitError
    eventCreate exitClean
    declare -g __TH_KEEP_EXIT=true
    _essentials_trapBridge_install EXIT
}
_essentials_trapBridge_presets_init
