#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Logger
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-09-24
# Description:   Leveled console output, one log file per scope, and a compose file that merges scopes.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_essentials_logger_init() {
    _essentials_init_isDone logger && return 0

    local -n config="essentials_config"
    declare -g LOG_COLOR="${config[LOG_COLOR]:-true}"

    # shellcheck source=./logger_counts.sh
    _loadEssential "logger/logger_counts.sh"

    # shellcheck source=./logger_output.sh
    _loadEssential "logger/logger_output.sh"
    _essentials_logger_output_init \
        "${config[LOG_MINLEVEL]:-info}" \
        "${config[LOG_STDERRLEVEL]:-warn}" || return 1
    unset -f _essentials_logger_output_init

    # shellcheck source=./logger_formatter.sh
    _loadEssential "logger/logger_formatter.sh"
    _essentials_logger_formatter_init "${config[LOG_INDENT]:-0}"
    unset -f _essentials_logger_formatter_init

    # shellcheck source=./logger_scopes.sh
    _loadEssential "logger/logger_scopes.sh"
    _essentials_logger_scopes_init \
        "${config[LOG_ROOT]:-/tmp/logs}" \
        "${config[LOG_PURGE]:-false}" || return 1
    unset -f _essentials_logger_scopes_init

    # shellcheck source=./logger_compose.sh
    _loadEssential "logger/logger_compose.sh"
    _essentials_logger_compose_init "${config[LOG_COMPOSE_FILENAME]:-compose.log}" || return 1
    unset -f _essentials_logger_compose_init

    _essentials_init_mark logger
}
_essentials_logger_init || return 1
