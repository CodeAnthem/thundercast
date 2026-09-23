#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast - bashTestSuite logger
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-20 | Modified: 2026-09-20
# ==================================================================================================

_bts_logger_init() {
    if [[ "${bts_config[color]}" == 1 ]]; then
        bts_config[log_debug]=$'\033[35mDEBUG\033[0m'
        bts_config[log_info]=$'\033[36mINFO\033[0m'
        bts_config[log_warn]=$'\033[33mWARN\033[0m'
        bts_config[log_error]=$'\033[31mERROR\033[0m'
        bts_config[log_fatal]=$'\033[31mFATAL\033[0m'
    else
        bts_config[log_debug]=DEBUG
        bts_config[log_info]=INFO
        bts_config[log_warn]=WARN
        bts_config[log_error]=ERROR
        bts_config[log_fatal]=FATAL
    fi
}

bts_log() {
    local level="$1" msg="$2"
    local tag
    case "$level" in
        debug)
            [[ "${bts_config[debug]}" == 1 ]] || return 0
            tag="${bts_config[log_debug]}"
            ;;
        info) tag="${bts_config[log_info]}" ;;
        warn) tag="${bts_config[log_warn]}" ;;
        error) tag="${bts_config[log_error]}" ;;
        fatal) tag="${bts_config[log_fatal]}" ;;
        *) tag="$level" ;;
    esac
    printf '  [%s] %s\n' "$tag" "$msg" >&2
    [[ "$level" == fatal ]] && return 1
    return 0
}

bts_debug() { bts_log debug "$1"; }
bts_info() { bts_log info "$1"; }
bts_warn() { bts_log warn "$1"; }
bts_error() { bts_log error "$1"; }
bts_fatal() { bts_log fatal "$1"; }

# Untagged status line (quiet OK / FAIL n path).
bts_status() {
    printf '%s\n' "$1" >&2
}
