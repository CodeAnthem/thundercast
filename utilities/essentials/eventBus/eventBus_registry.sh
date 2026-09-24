#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Event Bus - Registry
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-17 | Modified: 2026-09-24
# Description:   Creates events and stores their hooks.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

declare -ga __EH_EVENT=()
declare -ga __EH_FUNC=()
declare -ga __EH_PRIO=()
declare -ga __EH_SEQ=()
declare -gA __EH_CREATED=()
declare -gA __EH_DEDUPE=()
declare -g __EH_SEQ_NEXT=0

_essentials_eventBus_requireName() {
    [[ "$1" =~ ^[A-Za-z][A-Za-z0-9._:-]*$ ]] || {
        echo "[ERROR] - [EventBus] - Invalid event name: ${1:-}" >&2
        return 1
    }
}

_essentials_eventBus_requireFunction() {
    declare -f "$1" &>/dev/null || {
        echo "[ERROR] - [EventBus] - Function not found: ${1:-}" >&2
        return 1
    }
}

_essentials_eventBus_hookCount() {
    local event="$1"
    local n=0 i
    for i in "${!__EH_EVENT[@]}"; do
        [[ "${__EH_EVENT[i]}" == "$event" ]] && n=$((n + 1))
    done
    printf '%s\n' "$n"
}

eventCreate() {
    local event="${1:-}"
    _essentials_eventBus_requireName "$event" || return 1
    __EH_CREATED[$event]=1
    return 0
}

eventHas() {
    local event="${1:-}"
    _essentials_eventBus_requireName "$event" || return 1
    [[ -n "${__EH_CREATED[$event]:-}" ]]
}

eventHookCount() {
    local event="${1:-}"
    _essentials_eventBus_requireName "$event" || return 1
    _essentials_eventBus_hookCount "$event"
}

eventRegister() {
    local event="${1:-}"
    local func="${2:-}"
    local priority="${3:-50}"

    _essentials_eventBus_requireName "$event" || return 1
    _essentials_eventBus_requireFunction "$func" || return 1
    [[ "$priority" =~ ^[0-9]+$ ]] || {
        echo "[ERROR] - [EventBus] - Priority must be a non-negative integer: ${priority}" >&2
        return 1
    }

    local dedupe="${event}::${func}"
    [[ -z "${__EH_DEDUPE[$dedupe]:-}" ]] || return 0

    eventHas "$event" || eventCreate "$event" || return 1

    __EH_EVENT+=("$event")
    __EH_FUNC+=("$func")
    __EH_PRIO+=("$priority")
    __EH_SEQ+=("$__EH_SEQ_NEXT")
    __EH_SEQ_NEXT=$((__EH_SEQ_NEXT + 1))
    __EH_DEDUPE[$dedupe]=1
    return 0
}

eventUnregister() {
    local event="${1:-}"
    local func="${2:-}"

    _essentials_eventBus_requireName "$event" || return 1
    [[ -n "$func" ]] || {
        echo "[ERROR] - [EventBus] - Function name is required" >&2
        return 1
    }

    local dedupe="${event}::${func}"
    [[ -n "${__EH_DEDUPE[$dedupe]:-}" ]] || return 0

    local -a _eh_e=() _eh_f=() _eh_p=() _eh_s=()
    local i
    for i in "${!__EH_EVENT[@]}"; do
        if [[ "${__EH_EVENT[i]}" == "$event" && "${__EH_FUNC[i]}" == "$func" ]]; then
            continue
        fi
        _eh_e+=("${__EH_EVENT[i]}")
        _eh_f+=("${__EH_FUNC[i]}")
        _eh_p+=("${__EH_PRIO[i]}")
        _eh_s+=("${__EH_SEQ[i]}")
    done
    unset "__EH_DEDUPE[$dedupe]"
    __EH_EVENT=("${_eh_e[@]+"${_eh_e[@]}"}")
    __EH_FUNC=("${_eh_f[@]+"${_eh_f[@]}"}")
    __EH_PRIO=("${_eh_p[@]+"${_eh_p[@]}"}")
    __EH_SEQ=("${_eh_s[@]+"${_eh_s[@]}"}")
    return 0
}
