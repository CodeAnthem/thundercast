#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Logger Output
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-09-24
# Description:   Level map, quiet writers, and the console and file write path.
# ==================================================================================================

# Block Script Execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

# Highest to lowest. `log` is not a severity — it is never quiet and not in this list.
declare -ga __LOGGER_LEVELS=( fatal error warn info debug verbose )
declare -gA __LOGGER_LEVEL_SET=()
declare -g __LOGGER_MINLEVEL=""
declare -g __LOGGER_STDERRLEVEL=""

logger_isLevel() {
    [[ -n "${1:-}" ]] && [[ -n "${__LOGGER_LEVEL_SET[$1]+_}" ]]
}

_essentials_logger_requireLevel() {
    local name=$1
    local level=$2
    logger_isLevel "$level" && return 0
    echo "[ERROR] - [Logger] - Invalid ${name}: '${level:-}'" >&2
    return 1
}

_essentials_logger_build_quietmap() {
    local minLevel=$1
    declare -gA __LOGGER_OUTPUT_QUIETMAP=()
    local isQuiet=false
    local l
    for l in "${__LOGGER_LEVELS[@]}"; do
        if [[ "$l" == "error" || "$l" == "fatal" ]]; then
            __LOGGER_OUTPUT_QUIETMAP[$l]=false
        else
            __LOGGER_OUTPUT_QUIETMAP[$l]=$isQuiet
        fi
        [[ "$l" == "$minLevel" ]] && isQuiet=true
    done
    declare -g __LOGGER_MINLEVEL="$minLevel"
}

_essentials_logger_build_stderrmap() {
    local stderrLevel=$1
    declare -gA __LOGGER_OUTPUT_STDERRMAP=()
    local toStderr=true
    local l
    for l in "${__LOGGER_LEVELS[@]}"; do
        __LOGGER_OUTPUT_STDERRMAP[$l]=$toStderr
        [[ "$l" == "$stderrLevel" ]] && toStderr=false
    done
    declare -g __LOGGER_STDERRLEVEL="$stderrLevel"
}

# Bind public log/verbose/debug/info/warn/error. Quiet levels are nops.
# fatal always logs, then exits (default code 1). EXIT traps still run.
_essentials_logger_bind_writers() {
    local level
    for level in log "${__LOGGER_LEVELS[@]}"; do
        case "$level" in
            log|verbose|debug|info|warn|error) ;;
            fatal)
                fatal() {
                    _essentials_logger_output fatal "$1"
                    local code=${2:-1}
                    [[ "$code" =~ ^[0-9]+$ ]] || code=1
                    exit "$code"
                }
                continue
                ;;
            *) return 1 ;;
        esac

        if [[ "${__LOGGER_OUTPUT_QUIETMAP[$level]:-}" == true ]]; then
            eval "${level}() { return 0; }"
        else
            eval "${level}() { _essentials_logger_output ${level} \"\$@\"; }"
        fi
    done
}

logger_setMinLevel() {
    local minLevel=${1:-}
    _essentials_logger_requireLevel LOG_MINLEVEL "$minLevel" || return 1
    _essentials_logger_build_quietmap "$minLevel"
    _essentials_logger_bind_writers || return 1
}

# Initialize Logger Output
_essentials_logger_output_init() {
    local minLevel=$1
    local stderrLevel=$2
    local l

    __LOGGER_LEVEL_SET=()
    for l in "${__LOGGER_LEVELS[@]}"; do
        __LOGGER_LEVEL_SET[$l]=1
    done

    _essentials_logger_requireLevel LOG_MINLEVEL "$minLevel" || return 1
    _essentials_logger_requireLevel LOG_STDERRLEVEL "$stderrLevel" || return 1

    _essentials_logger_build_quietmap "$minLevel"
    _essentials_logger_build_stderrmap "$stderrLevel"
    _essentials_logger_bind_writers || return 1
}

_essentials_logger_output() {
    local level=$1
    local message=$2
    local destination=${3:-both}
    local scope=${4:-${__LOGGER_SCOPE_CURRENT:-}}

    # Check if we skip
    [[ "${__LOGGER_OUTPUT_QUIETMAP[$level]:-}" == true ]] && return 0

    case "$level" in
        error|fatal) logger_markError ;;
        warn) logger_markWarn ;;
    esac

    case "$destination" in
        console) _essentials_logger_console "$message" "$level";;
        file) _essentials_logger_file "$message" "$level" "$scope";;
        both)
            _essentials_logger_console "$message" "$level"
            _essentials_logger_file "$message" "$level" "$scope"
            ;;
        *)
            _essentials_logger_output error "Invalid destination: $destination" console
            return 1
            ;;
    esac

    return 0
}

_essentials_logger_console() {
    local message=$1
    local level=$2
    local dest=1
    [[ "${__LOGGER_OUTPUT_STDERRMAP[$level]:-}" == true ]] && dest=2

    # Direct Output
    if [[ "$level" == "log" ]]; then
        printf '%s\n' "$message" >&"$dest"
        return
    fi

    # Colored Output
    local label
    if [[ "${LOG_COLOR:-false}" == true ]]; then
        label=${__LOGGER_FORMATTED_LEVELS["${level}_color"]}
        printf '%s%s%s\n' "$label" " $message" $'\033[0m' >&"$dest"
        return
    fi

    # Plain Output
    label=${__LOGGER_FORMATTED_LEVELS["${level}_plain"]}
    printf '%s%s\n' "$label" " $message" >&"$dest"
}

_essentials_logger_file() {
    local message=$1
    local level=$2
    local scope=${3:-${__LOGGER_SCOPE_CURRENT:-}}

    # Direct Output
    if [[ "$level" == "log" ]]; then
        _essentials_logger_scope_write "$message" "$scope"
        return 0
    fi

    # Time formatted output
    local label date_time
    label=${__LOGGER_FORMATTED_LEVELS["${level}_file"]}
    printf -v date_time "%(%Y-%m-%d %H:%M:%S)T" -1

    _essentials_logger_scope_write "${date_time} ${label} ${message}" "$scope"
}
