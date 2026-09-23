#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Trap Bridge - Dispatch
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-17 | Modified: 2026-09-17
# ==================================================================================================
#
# Maps a signal to event `trap.<SIGNAL>` and installs one dispatcher for that
# signal. Does not wrap the trap builtin. A later raw `trap` still last-wins.
# On install, a pre-existing handler is remembered and run after eventRun.
#
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

declare -gA __TH_INSTALLED=()
declare -gA __TH_PREV=()
declare -g __TRAP_LAST_EXIT_CODE=0

# Overwritten by trapBridge_presets.sh when that module is loaded.
_essentials_trapBridge_onPresetExit() { return 0; }

_essentials_trapBridge_normalize() {
    local raw="${1:-}"
    raw="${raw#SIG}"
    case "$raw" in
        exit|EXIT|0) printf '%s\n' EXIT ;;
        *) printf '%s\n' "${raw^^}" ;;
    esac
}

_essentials_trapBridge_snapshot() {
    local signal="$1"
    local spec=""
    spec=${ trap -p "$signal" 2>/dev/null; } || spec=""
    [[ "$spec" == *_essentials_trapBridge_dispatch* ]] && return 0
    __TH_PREV[$signal]="$spec"
}

_essentials_trapBridge_chain() {
    local signal="$1"
    local spec="${__TH_PREV[$signal]:-}"
    [[ -n "$spec" ]] || return 0
    local -a _th_words=()
    eval "_th_words=( ${spec} )"
    local handler="${_th_words[2]:-}"
    [[ -n "$handler" ]] || return 0
    eval "$handler" || true
}

_essentials_trapBridge_restore() {
    local signal="$1"
    local spec="${__TH_PREV[$signal]:-}"
    if [[ -n "$spec" ]]; then
        eval "$spec"
    else
        trap - "$signal"
    fi
    unset "__TH_INSTALLED[$signal]"
    unset "__TH_PREV[$signal]"
}

_essentials_trapBridge_dispatch() {
    local code=$?
    local signal="$1"
    [[ "$signal" == EXIT ]] && __TRAP_LAST_EXIT_CODE=$code

    local event="trap.${signal}"
    if eventHas "$event"; then
        eventRun "$event" "$code" || true
    fi

    if [[ "$signal" == EXIT ]]; then
        _essentials_trapBridge_onPresetExit "$code"
    fi

    _essentials_trapBridge_chain "$signal"
    return 0
}

_essentials_trapBridge_bind() {
    local signal="$1"
    # Expand signal now so the dispatcher knows which trap fired.
    # shellcheck disable=SC2064
    trap "_essentials_trapBridge_dispatch ${signal}" "$signal"
}

_essentials_trapBridge_install() {
    local signal="$1"
    [[ -z "${__TH_INSTALLED[$signal]:-}" ]] || return 0
    _essentials_trapBridge_snapshot "$signal"
    _essentials_trapBridge_bind "$signal"
    __TH_INSTALLED[$signal]=1
}

_essentials_trapBridge_maybeUninstall() {
    local signal="$1"
    local event="trap.${signal}" n
    n=${ _essentials_eventBus_hookCount "$event"; }
    [[ "$n" -gt 0 ]] && return 0
    [[ "$signal" == EXIT && "${__TH_KEEP_EXIT:-false}" == true ]] && return 0
    _essentials_trapBridge_restore "$signal"
}

trapRegister() {
    local raw="${1:-}"
    local func="${2:-}"
    local priority="${3:-50}"
    local signal event

    signal=${ _essentials_trapBridge_normalize "$raw"; }
    [[ -n "$signal" ]] || {
        echo "[ERROR] - [TrapBridge] - Signal is required" >&2
        return 1
    }

    event="trap.${signal}"
    eventRegister "$event" "$func" "$priority" || return 1
    _essentials_trapBridge_install "$signal"
}

trapUnregister() {
    local raw="${1:-}"
    local func="${2:-}"
    local signal event

    signal=${ _essentials_trapBridge_normalize "$raw"; }
    event="trap.${signal}"
    eventUnregister "$event" "$func" || return 1
    _essentials_trapBridge_maybeUninstall "$signal"
}
