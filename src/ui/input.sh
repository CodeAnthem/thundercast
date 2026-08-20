#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI - TTY input guard
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-20 | Modified: 2026-08-20
# Description:   Discard keystrokes when no prompt is active; Ctrl+C still aborts
# ==================================================================================================

declare -g _NDS_UI_INPUT_GUARD=0
declare -g _NDS_UI_INPUT_STTY=""
declare -g _NDS_UI_PROMPT_DEPTH=0

# Description: True when the controlling TTY can be used for input.
_nds_ui_tty_ok() {
    [[ -c /dev/tty && -r /dev/tty && -w /dev/tty ]]
}

# Description: Discard typeahead so a missed paste cannot answer the next prompt.
# No-op when there is no controlling TTY (unattended / ssh without -t).
_nds_ui_drain_tty() {
    local _chunk
    _nds_ui_tty_ok || return 0
    {
        while IFS= read -r -t 0 -n 256 _chunk; do
            :
        done
    } </dev/tty 2>/dev/null || true
    return 0
}

_nds_ui_input_restore_stty() {
    [[ -n "${_NDS_UI_INPUT_STTY:-}" ]] || return 0
    stty "$_NDS_UI_INPUT_STTY" </dev/tty 2>/dev/null || true
}

# Description: No echo, drop queued keys, keep ISIG so Ctrl+C still aborts.
_nds_ui_input_idle_stty() {
    _nds_ui_tty_ok || return 0
    stty -echo isig -icanon min 0 time 0 </dev/tty 2>/dev/null || true
    _nds_ui_drain_tty
}

# Description: SIGINT handler — restore TTY, then abort (exit 130).
_nds_ui_session_sigint() {
    nds_ui_input_guard_disable
    declare -f newline &>/dev/null && newline
    exit 130
}

# Description: Start discarding TTY input until nds_ui_prompt_enter (or disable).
# Call from the live session only — not from selftests.
nds_ui_input_guard_enable() {
    [[ "${_NDS_UI_INPUT_GUARD:-0}" == "1" ]] && return 0
    _nds_ui_tty_ok || return 0
    _NDS_UI_INPUT_STTY="$(stty -g </dev/tty 2>/dev/null || true)"
    [[ -n "${_NDS_UI_INPUT_STTY}" ]] || return 0
    _NDS_UI_INPUT_GUARD=1
    _NDS_UI_PROMPT_DEPTH=0
    _nds_ui_input_idle_stty
}

# Description: Restore the TTY (EXIT / SIGINT).
nds_ui_input_guard_disable() {
    _nds_ui_input_restore_stty
    _NDS_UI_INPUT_GUARD=0
    _NDS_UI_PROMPT_DEPTH=0
}

# Description: Lift the guard for an interactive read. Nestable.
nds_ui_prompt_enter() {
    _NDS_UI_PROMPT_DEPTH=$((${_NDS_UI_PROMPT_DEPTH:-0} + 1))
    if [[ "${_NDS_UI_PROMPT_DEPTH}" -eq 1 && "${_NDS_UI_INPUT_GUARD:-0}" == "1" ]]; then
        _nds_ui_input_restore_stty
    fi
    _nds_ui_drain_tty
}

# Description: Resume discarding input when the outermost prompt ends.
nds_ui_prompt_leave() {
    local depth="${_NDS_UI_PROMPT_DEPTH:-0}"
    if (( depth > 0 )); then
        _NDS_UI_PROMPT_DEPTH=$((depth - 1))
    fi
    if [[ "${_NDS_UI_PROMPT_DEPTH}" -eq 0 && "${_NDS_UI_INPUT_GUARD:-0}" == "1" ]]; then
        _nds_ui_input_idle_stty
    fi
}

# Description: bash read from /dev/tty with the input guard lifted.
# Arguments: passed to read (do not redirect stdin).
nds_ui_tty_read() {
    local rc=0
    nds_ui_prompt_enter
    # shellcheck disable=SC2162
    read "$@" </dev/tty
    rc=$?
    nds_ui_prompt_leave
    return "$rc"
}
