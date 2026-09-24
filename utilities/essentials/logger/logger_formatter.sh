#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Logger Formatter
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-09-24
# Description:   Console labels and the indent applied to them.
# ==================================================================================================

# Block Script Execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

# Initialize Logger Formatter
_essentials_logger_formatter_init() {
    local indent=$1
    local -A level_tags=(
        [verbose]='[VERBOSE]'
        [debug]='[DEBUG]'
        [info]='[INFO] '
        [warn]='[WARN] '
        [error]='[ERROR]'
        [fatal]='[FATAL]'
    )
    local -A level_colors=(
        [verbose]=$'\033[38;5;240m'
        [debug]=$'\033[38;5;215m'
        [info]=$'\033[38;5;77m'
        [warn]=$'\033[38;5;228m'
        [error]=$'\033[38;5;197m'
        [fatal]=$'\033[38;5;196m'
    )
    local -A colors_text=(
        [verbose]=$'\033[38;5;243m'
        [debug]=""
        [info]=""
        [warn]=""
        [error]=""
        [fatal]=$'\033[38;5;196m'
    )

    declare -gA __LOGGER_FORMATTED_LEVELS=()
    local reset=$'\033[0m' indentation level level_tag
    printf -v indentation '%*s' "$indent" ''

    for level in "${__LOGGER_LEVELS[@]}"; do
        level_tag=${level_tags[$level]}
        __LOGGER_FORMATTED_LEVELS["${level}_file"]="${level_tag} -"
        __LOGGER_FORMATTED_LEVELS["${level}_plain"]="${indentation}${level_tag} -"
        __LOGGER_FORMATTED_LEVELS["${level}_color"]="${indentation}${level_colors[$level]}${level_tag}${reset} -${colors_text[$level]}"
    done
}
