#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Logger - Counts
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-17 | Modified: 2026-09-24
# Description:   Session error and warn counters.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

declare -g __LOGGER_ERROR_COUNT=0
declare -g __LOGGER_WARN_COUNT=0

logger_markError() {
    __LOGGER_ERROR_COUNT=$((__LOGGER_ERROR_COUNT + 1))
}

logger_markWarn() {
    __LOGGER_WARN_COUNT=$((__LOGGER_WARN_COUNT + 1))
}

logger_hasError() {
    [[ "${__LOGGER_ERROR_COUNT:-0}" -gt 0 ]]
}

logger_hasWarn() {
    [[ "${__LOGGER_WARN_COUNT:-0}" -gt 0 ]]
}

logger_resetCounts() {
    __LOGGER_ERROR_COUNT=0
    __LOGGER_WARN_COUNT=0
}
