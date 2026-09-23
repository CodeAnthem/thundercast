#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Event Bus - Dispatch
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-17 | Modified: 2026-09-17
# ==================================================================================================
#
# Hook results:
#   return 0                 — continue
#   return 0 after eventStop — skip remaining hooks (not an error)
#   return non-zero          — abort remaining hooks; return that code
#
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

declare -g __EVENT_DISPATCHING=false
declare -g __EVENT_STOP=0

_essentials_eventBus_hookBefore() {
    local i="$1" j="$2"
    local pi="${__EH_PRIO[i]}" pj="${__EH_PRIO[j]}"
    ((pi < pj)) && return 0
    ((pi > pj)) && return 1
    ((__EH_SEQ[i] < __EH_SEQ[j]))
}

_essentials_eventBus_sortedIndices() {
    local event="$1"
    local -n _eh_out="$2"
    local i j inserted
    local -a _eh_next=()
    _eh_out=()
    for i in "${!__EH_EVENT[@]}"; do
        [[ "${__EH_EVENT[i]}" == "$event" ]] || continue
        inserted=false
        _eh_next=()
        for j in "${_eh_out[@]}"; do
            if [[ "$inserted" == false ]] && _essentials_eventBus_hookBefore "$i" "$j"; then
                _eh_next+=("$i")
                inserted=true
            fi
            _eh_next+=("$j")
        done
        [[ "$inserted" == false ]] && _eh_next+=("$i")
        _eh_out=("${_eh_next[@]}")
    done
}

eventRun() {
    local event="${1:-}"
    _essentials_eventBus_requireName "$event" || return 1
    shift

    eventHas "$event" || {
        echo "[ERROR] - [EventBus] - Unknown event: ${event}" >&2
        return 1
    }

    if [[ "${__EVENT_DISPATCHING}" == true ]]; then
        case "$event" in
            exit|exitError|exitClean) ;;
            *)
                echo "[ERROR] - [EventBus] - Re-entrant eventRun is not allowed (${event})" >&2
                return 1
                ;;
        esac
    fi

    local -a _eh_order=()
    local prev_dispatch="${__EVENT_DISPATCHING}"
    _essentials_eventBus_sortedIndices "$event" _eh_order

    __EVENT_DISPATCHING=true
    __EVENT_STOP=0

    local _eh_i _eh_func rc=0
    for _eh_i in "${_eh_order[@]}"; do
        _eh_func="${__EH_FUNC[_eh_i]}"
        rc=0
        "$_eh_func" "$@" || rc=$?
        ((rc != 0)) && break
        [[ "${__EVENT_STOP}" -eq 1 ]] && break
    done

    __EVENT_DISPATCHING="${prev_dispatch}"
    __EVENT_STOP=0
    ((rc != 0)) && return "$rc"
    return 0
}

eventStop() {
    [[ "${__EVENT_DISPATCHING}" == true ]] || {
        echo "[ERROR] - [EventBus] - eventStop is only valid during eventRun" >&2
        return 1
    }
    __EVENT_STOP=1
    return 0
}
