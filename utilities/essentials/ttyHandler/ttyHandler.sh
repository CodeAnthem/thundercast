#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - TTY
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-18 | Modified: 2026-09-18
# ==================================================================================================
#
# TTY policy: idle discard, cooked/hidden/cbreak, key allowlists, restore on EXIT.
# Does not prompt. A thin read wrapper only forces /dev/tty.
#
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_essentials_tty_init() {
    _essentials_init_isDone ttyHandler && return 0

    local -n config="essentials_config"
    local prio="${config[TTY_EXIT_PRIORITY]:-10}"
    if ! [[ "$prio" =~ ^[0-9]+$ ]]; then
        error "Tty: invalid TTY_EXIT_PRIORITY: ${prio}"
        return 1
    fi

    declare -g __TTY_EXIT_PRIORITY="$prio"
    declare -g __TTY_GUARD=0
    declare -g __TTY_STTY=""
    declare -g __TTY_DEPTH=0
    declare -g __TTY_POLICY=cooked
    declare -g __TTY_READ_TICK=""
    declare -g __TTY_TICK_HOOK=""
    declare -g __TTY_READING=0
    declare -g __TTY_ALLOW_BODY=""
    declare -gA __TTY_ALLOW_SET=()

    # shellcheck source=./tty_controller.sh
    loadModule "ttyHandler/tty_controller.sh"
    # shellcheck source=./tty_presets.sh
    loadModule "ttyHandler/tty_presets.sh"

    if declare -f eventRegister &>/dev/null; then
        eventRegister exit tty_restore "${__TTY_EXIT_PRIORITY}" || return 1
    fi

    _essentials_init_mark ttyHandler
}
_essentials_tty_init || return 1
