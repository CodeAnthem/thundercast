#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Chrome
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-21 | Modified: 2026-09-21
# ==================================================================================================
#
# Optional header/footer frame on the alt screen. Off until chrome_begin. Does not prompt.
# While on, fd 2 (and a terminal fd 1) is a tee (chrome_hist.sh); every direct paint syncs first.
# Bars: chrome_bars.sh. Size / region / primitives: chrome_layout.sh.
#
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_essentials_chrome_init() {
    [[ "${__CHROME_INITIALIZED:-false}" == true ]] && return 0

    local -n config="essentials_config"
    local prio="${config[CHROME_EXIT_PRIORITY]:-5}" key
    if ! [[ "$prio" =~ ^[0-9]+$ ]]; then
        error "Chrome: invalid CHROME_EXIT_PRIORITY: ${prio}"
        return 1
    fi

    declare -g __CHROME_EXIT_PRIORITY="$prio"
    declare -g __CHROME_ON=0
    declare -g __CHROME_SUSPENDED=0
    declare -g __CHROME_TEMP=0
    declare -g __CHROME_MOUSE=0
    declare -g __CHROME_HEADER_BG="${config[CHROME_HEADER_BG]:-reverse}"
    declare -g __CHROME_HEADER_FG="${config[CHROME_HEADER_FG]:-}"
    declare -g __CHROME_FOOTER_BG="${config[CHROME_FOOTER_BG]:-reverse}"
    declare -g __CHROME_FOOTER_FG="${config[CHROME_FOOTER_FG]:-}"
    declare -g __CHROME_HEADER_ROWS="${config[CHROME_HEADER_ROWS]:-2}"
    declare -g __CHROME_FOOTER_ROWS="${config[CHROME_FOOTER_ROWS]:-1}"
    declare -g __CHROME_TEMP_ROWS="${config[CHROME_TEMP_ROWS]:-12}"
    declare -g __CHROME_HIST_MAX="${config[CHROME_HIST_MAX]:-1000}"
    declare -g __CHROME_HEADER_SHOW=2
    declare -g __CHROME_FOOTER_SHOW=1
    declare -g __CHROME_LINES=24
    declare -g __CHROME_COLS=80
    declare -g __CHROME_BODY_TOP=3
    declare -g __CHROME_BODY_BOT=23
    declare -g __CHROME_TEMP_TOP=0
    declare -g __CHROME_LOG_ROW=3
    declare -g __CHROME_WINCH=0
    declare -g __CHROME_WINCH_PENDING=0
    declare -g __CHROME_SCROLL=0
    declare -g __CHROME_TTY=""
    declare -g __CHROME_ERR=""
    declare -g __CHROME_OUT=""
    declare -g __CHROME_ACK=""
    declare -g __CHROME_HIST_PATH=""
    declare -g __CHROME_ACK_PATH=""
    declare -g __CHROME_VIEW_BASE=0
    declare -g __CHROME_FILTERED=""
    declare -g __CHROME_FILTERED_UP=0
    declare -ga __CHROME_VIEW=()

    for key in CHROME_HEADER_ROWS CHROME_FOOTER_ROWS; do
        local -n _chrome_rows="__${key}"
        if ! [[ "$_chrome_rows" =~ ^[0-9]+$ ]] || (( _chrome_rows > 20 )); then
            error "Chrome: invalid ${key}: ${_chrome_rows}"
            return 1
        fi
        unset -n _chrome_rows
    done
    if ! [[ "$__CHROME_HIST_MAX" =~ ^[1-9][0-9]*$ ]]; then
        error "Chrome: invalid CHROME_HIST_MAX: ${__CHROME_HIST_MAX}"
        return 1
    fi
    if ! [[ "$__CHROME_TEMP_ROWS" =~ ^[1-9][0-9]*$ ]]; then
        error "Chrome: invalid CHROME_TEMP_ROWS: ${__CHROME_TEMP_ROWS}"
        return 1
    fi

    # shellcheck source=./chrome_layout.sh
    loadModule "chrome/chrome_layout.sh"
    # shellcheck source=./chrome_bars.sh
    loadModule "chrome/chrome_bars.sh"
    # shellcheck source=./chrome_hist.sh
    loadModule "chrome/chrome_hist.sh"
    _chrome_barsInit

    if declare -f eventRegister &>/dev/null; then
        eventRegister exit chrome_end "${__CHROME_EXIT_PRIORITY}" || return 1
    fi

    declare -g __CHROME_INITIALIZED=true
}

chrome_isOn() {
    [[ "${__CHROME_ON:-0}" == 1 ]]
}

chrome_isSuspended() {
    [[ "${__CHROME_SUSPENDED:-0}" == 1 ]]
}

# ---- frame --------------------------------------------------------------------------------------

_chrome_openTty() {
    if declare -f tty_ok &>/dev/null; then
        tty_ok || return 1
    else
        { :; } 2>/dev/null </dev/tty || return 1
    fi
    exec {__CHROME_TTY}>/dev/tty 2>/dev/null || {
        __CHROME_TTY=""
        return 1
    }
}

_chrome_closeTty() {
    if [[ -n "${__CHROME_TTY:-}" ]]; then
        exec {__CHROME_TTY}>&-
        __CHROME_TTY=""
    fi
}

# Alt screen + mouse. tty reads are sliced while on so a resize redraws while a prompt waits;
# the WINCH trap only flags it and _chrome_tick paints between slices (see tty_read).
_chrome_enter() {
    _chrome_printf '\033[?1049h\033[2J\033[H\033[?25h'
    chrome_setMouse on
    __CHROME_WINCH_PENDING=0
    declare -g __TTY_READ_TICK=0.25
    declare -g __TTY_TICK_HOOK=_chrome_tick
}

# Called with __CHROME_ON already 0, so mouse off is direct here.
_chrome_leave() {
    _chrome_printf '\033[?1000l\033[?1006l\033[r\033[?25h\033[?1049l'
    __CHROME_MOUSE=0
    declare -g __TTY_READ_TICK=""
    declare -g __TTY_TICK_HOOK=""
}

_chrome_tick() {
    (( ${__CHROME_WINCH_PENDING:-0} )) || return 0
    __CHROME_WINCH_PENDING=0
    chrome_isOn && _chrome_redraw
    return 0
}

_chrome_winchOn() {
    if declare -f trapRegister &>/dev/null; then
        trapRegister WINCH chrome_onWinch || true
        __CHROME_WINCH=1
    else
        trap chrome_onWinch WINCH
        __CHROME_WINCH=2
    fi
}

_chrome_winchOff() {
    if [[ "${__CHROME_WINCH:-0}" == 1 ]] && declare -f trapUnregister &>/dev/null; then
        trapUnregister WINCH chrome_onWinch 2>/dev/null || true
    elif [[ "${__CHROME_WINCH:-0}" == 2 ]]; then
        trap - WINCH
    fi
    __CHROME_WINCH=0
}

# Alt screen, bars, DECSTBM, hist tee, SGR mouse. No-op without a TTY or if already on.
# [subtitle] fills header row 1. rc 1 only when the tee cannot start — the alt screen is left again.
chrome_begin() {
    chrome_isOn && return 0
    chrome_isSuspended && {
        chrome_resume
        return $?
    }
    _chrome_openTty || return 0
    (( $# > 0 )) && chrome_setSubtitle "$1"
    __CHROME_SCROLL=0
    __CHROME_ON=1
    _chrome_enter
    _chrome_termSize
    _chrome_drawBars
    _chrome_region
    _chrome_parkHome
    if ! _chrome_histStart; then
        _chrome_leave
        _chrome_closeTty
        __CHROME_ON=0
        return 1
    fi
    _chrome_winchOn
}

# Flush the tee, restore fds, mouse off, reset region, leave the alt screen. Idempotent. EXIT hook.
chrome_end() {
    _chrome_winchOff
    if chrome_isSuspended; then
        __CHROME_SUSPENDED=0
        _chrome_histFiles rm
        _chrome_closeTty
        return 0
    fi
    [[ "${__CHROME_ON:-0}" == 1 ]] || return 0
    __CHROME_TEMP=0
    __CHROME_ON=0
    _chrome_histStop
    _chrome_leave
    _chrome_closeTty
    return 0
}

# Leave the frame for an external full-screen program; history is kept. chrome_isOn is false until
# chrome_resume, so other features print like on a plain console meanwhile.
chrome_suspend() {
    chrome_isOn || return 0
    __CHROME_TEMP=0
    __CHROME_ON=0
    __CHROME_SUSPENDED=1
    _chrome_histStop keep
    _chrome_leave
    return 0
}

# Back into the frame after chrome_suspend: alt screen, tee on the kept history, full redraw.
chrome_resume() {
    chrome_isSuspended || return 0
    __CHROME_SUSPENDED=0
    [[ -n "${__CHROME_TTY:-}" ]] || _chrome_openTty || {
        _chrome_histFiles rm
        return 0
    }
    __CHROME_ON=1
    _chrome_enter
    if ! _chrome_histStart; then
        _chrome_leave
        _chrome_closeTty
        __CHROME_ON=0
        return 1
    fi
    _chrome_redraw
}

# Run a command outside the frame: chrome_run vim /etc/hosts. Returns the command's rc.
chrome_run() {
    local rc=0
    (( $# > 0 )) || return 0
    if ! chrome_isOn; then
        "$@"
        return $?
    fi
    chrome_suspend
    "$@" || rc=$?
    chrome_resume
    return "$rc"
}

# Full repaint (bars + body from history). Use after something else drew on the screen.
chrome_redraw() {
    chrome_isOn || return 0
    _chrome_redraw
}

# Re-apply size + DECSTBM + bars without moving the body cursor. After stty.
chrome_repin() {
    chrome_isOn || return 0
    _chrome_sync
    _chrome_termSize
    _chrome_region
    _chrome_drawBars
}

# SGR mouse reporting (1000 + 1006). Prompt turns it off for cooked sessions.
chrome_setMouse() {
    chrome_isOn || return 0
    case "${1:-}" in
        on)
            (( __CHROME_MOUSE == 1 )) && return 0
            _chrome_printf '\033[?1000h\033[?1006h'
            __CHROME_MOUSE=1
            ;;
        off)
            (( __CHROME_MOUSE == 0 )) && return 0
            _chrome_printf '\033[?1000l\033[?1006l'
            __CHROME_MOUSE=0
            ;;
        *)
            error "chrome_setMouse: on|off"
            return 1
            ;;
    esac
}

chrome_getCols() {
    chrome_isOn || _chrome_termSize
    printf '%s' "$__CHROME_COLS"
}

chrome_getBodyRows() {
    chrome_isOn || _chrome_termSize
    printf '%s' $(( __CHROME_BODY_BOT - __CHROME_BODY_TOP + 1 ))
}

# ---- body erase (bars stay) ---------------------------------------------------------------------

# Wipe the body only. Cursor at the body top. History keeps the old lines; the live view starts here.
chrome_clear() {
    chrome_isOn || return 0
    _chrome_histClear
    _chrome_clearBody
    _chrome_parkHome
    _chrome_drawTitleRows
}

# Cursor to the body top. No erase.
chrome_home() {
    chrome_isOn || return 0
    _chrome_sync
    _chrome_parkHome
}

# Erase the current body row. Cursor stays on that row.
chrome_clearLine() {
    local row
    chrome_isOn || return 0
    row=${ _chrome_clampRow "${ _chrome_cursorRow; }"; }
    _chrome_printf '\033[%d;1H\033[K' "$row"
    __CHROME_LOG_ROW=$row
}

# Erase the last n body rows (inclusive of the current row). Cursor at the first wiped row.
chrome_clearLines() {
    local n="${1:-}" row start
    chrome_isOn || return 0
    [[ "$n" =~ ^[1-9][0-9]*$ ]] || return 0
    row=${ _chrome_clampRow "${ _chrome_cursorRow; }"; }
    start=${ _chrome_clampRow "$((row - n + 1))"; }
    _chrome_clearRange "$start" "$row"
    _chrome_printf '\033[%d;1H' "$start"
    __CHROME_LOG_ROW=$start
}

# Erase from the current row through the body bottom. Cursor stays on that row.
chrome_clearToEnd() {
    local row
    chrome_isOn || return 0
    row=${ _chrome_clampRow "${ _chrome_cursorRow; }"; }
    _chrome_clearRange "$row" "$__CHROME_BODY_BOT"
    _chrome_printf '\033[%d;1H' "$row"
    __CHROME_LOG_ROW=$row
}

# ---- temp slot ----------------------------------------------------------------------------------

chrome_isTemp() {
    [[ "${__CHROME_TEMP:-0}" == 1 ]]
}

# Mark the current body row. Later writes are wiped by chrome_tempEnd. The body stays one pane.
chrome_tempBegin() {
    chrome_isOn || return 0
    chrome_isTemp && return 0
    __CHROME_TEMP_TOP=${ _chrome_clampRow "${ _chrome_cursorRow; }"; }
    __CHROME_TEMP=1
}

# Erase from the mark to the bottom of the body. Log above the mark stays.
chrome_tempEnd() {
    chrome_isOn || return 0
    chrome_isTemp || return 0
    _chrome_sync
    _chrome_clearRange "$__CHROME_TEMP_TOP" "$__CHROME_BODY_BOT"
    _chrome_printf '\033[%d;1H' "$__CHROME_TEMP_TOP"
    __CHROME_LOG_ROW=$__CHROME_TEMP_TOP
    __CHROME_TEMP=0
    __CHROME_TEMP_TOP=0
}

# ---- resize -------------------------------------------------------------------------------------

# Full redraw: a resize can smear bar colours into the body, so wipe and rebuild from history.
# The pending prompt line comes back from the tee's partial mirror. While a tty_read is in
# flight only a flag is set — the redraw's own read -t would break that read's timer.
chrome_onWinch() {
    chrome_isOn || return 0
    if [[ "${__TTY_READING:-0}" == 1 ]]; then
        __CHROME_WINCH_PENDING=1
        return 0
    fi
    _chrome_redraw
}

_essentials_chrome_init || return 1
