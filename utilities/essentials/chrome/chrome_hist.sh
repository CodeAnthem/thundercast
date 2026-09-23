#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Chrome - Body history
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-21 | Modified: 2026-09-21
# ==================================================================================================
#
# fd 2 → tee → tty + history file. The parent never sees the bytes, so it talks to the tee with
# marker lines on fd 2 (\001chrome:…\001) and waits for an ack on a FIFO. That is what orders a
# direct tty paint (clear, bars, cursor) after everything the app already wrote.
#
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

declare -g __CHROME_MARK_SYNC=$'\001chrome:sync\001'
declare -g __CHROME_MARK_CLEAR=$'\001chrome:clear\001'

# ---- tee side (runs in the fd-2 process substitution) -------------------------------------------

# One stderr line (complete or pending) → what a redraw should show for it.
# Leading ESC[nA (menu redraw) drops the n previous lines. Other CSI except SGR go; \r keeps the
# tail; \b rubs out. Sets __CHROME_FILTERED and __CHROME_FILTERED_UP (rows to drop first).
_chrome_histLine() {
    local line="$1" pre
    local re=$'\e\\[[0-9;?<>=!]*[^0-9;?<>=!m]'
    __CHROME_FILTERED_UP=0
    if [[ "$line" =~ ^$'\e'\[([0-9]*)A ]]; then
        __CHROME_FILTERED_UP="${BASH_REMATCH[1]:-1}"
        line="${line:${#BASH_REMATCH[0]}}"
    fi
    while [[ "$line" =~ $re ]]; do
        line="${line/"${BASH_REMATCH[0]}"/}"
    done
    line="${line##*$'\r'}"
    while [[ "$line" == *$'\b'* ]]; do
        pre="${line%%$'\b'*}"
        line="${pre%?}${line#*$'\b'}"
    done
    __CHROME_FILTERED="$line"
}

# Append one line (or the clear marker) to the in-memory history and the file.
_chrome_teeAdd() {
    local line="$1" raw="${2:-0}" dirty=0 n i tmp path="${__CHROME_HIST_PATH:-}"
    [[ -n "$path" && -e "$path" ]] || return 0
    if [[ "$raw" == 1 ]]; then
        __CHROME_FILTERED="$line"
        __CHROME_FILTERED_UP=0
    else
        _chrome_histLine "$line"
    fi
    n="${__CHROME_FILTERED_UP}"
    for ((i = 0; i < n; i++)); do
        (( ${#__CHROME_TEE_HIST[@]} > 0 )) || break
        [[ "${__CHROME_TEE_HIST[-1]}" == "$__CHROME_MARK_CLEAR" ]] && break
        unset '__CHROME_TEE_HIST[-1]'
        dirty=1
    done
    __CHROME_TEE_HIST+=("$__CHROME_FILTERED")
    if (( ${#__CHROME_TEE_HIST[@]} > __CHROME_HIST_MAX + 200 )); then
        __CHROME_TEE_HIST=("${__CHROME_TEE_HIST[@]:${#__CHROME_TEE_HIST[@]}-__CHROME_HIST_MAX}")
        dirty=1
    fi
    if (( dirty )); then
        tmp="${path}.tmp"
        if (( ${#__CHROME_TEE_HIST[@]} > 0 )); then
            printf '%s\n' "${__CHROME_TEE_HIST[@]}" > "$tmp" || return 0
        else
            : > "$tmp" || return 0
        fi
        mv -f "$tmp" "$path" 2>/dev/null || rm -f "$tmp"
    else
        printf '%s\n' "$__CHROME_FILTERED" >> "$path"
    fi
}

# Forward bytes as they arrive (prompts and spinners are partial lines); record complete lines.
# One blocking byte, then the rest of the line with a short timeout → full lines cost nothing,
# a partial line shows after ~20 ms. A chunk holding \001 is held back until the line completes.
# The pending partial line is mirrored to <hist>.partial so a redraw can re-emit it.
_chrome_tee() {
    local c rest chunk pending="" complete held=0 rc head mark tty ack
    set +e +u +o pipefail
    trap '' INT QUIT
    declare -ga __CHROME_TEE_HIST=()
    if [[ -s "${__CHROME_HIST_PATH:-}" ]]; then
        mapfile -t __CHROME_TEE_HIST < "$__CHROME_HIST_PATH"
    fi
    if [[ -n "${__CHROME_TTY:-}" ]]; then
        tty="$__CHROME_TTY"
    else
        exec {tty}>/dev/tty || exit 0
    fi
    exec {ack}>"${__CHROME_ACK_PATH}" || exit 0
    while IFS= read -r -N 1 c; do
        complete=0
        rest=""
        if [[ "$c" == $'\n' ]]; then
            chunk=""
            complete=1
        else
            IFS= read -r -d $'\n' -n 32768 -t 0.02 rest
            rc=$?
            chunk="${c}${rest}"
            (( rc == 0 && ${#rest} < 32768 )) && complete=1
        fi
        pending+="$chunk"
        if (( held )); then
            :
        elif [[ "$chunk" == *$'\001'* ]]; then
            printf '%s' "${chunk%%$'\001'*}" >&"$tty"
            held=1
        else
            printf '%s' "$chunk" >&"$tty"
            (( complete )) && printf '\n' >&"$tty"
        fi
        if (( ! complete )); then
            (( held )) || _chrome_teePartial "$pending"
            continue
        fi
        if (( held )); then
            head="${pending%%$'\001'*}"
            mark=$'\001'"${pending#*$'\001'}"
            case "$mark" in
                "$__CHROME_MARK_SYNC")
                    pending="$head"
                    printf '1\n' >&"$ack"
                    ;;
                "$__CHROME_MARK_CLEAR")
                    _chrome_teeAdd "$__CHROME_MARK_CLEAR" 1
                    pending="$head"
                    printf '1\n' >&"$ack"
                    ;;
                *)
                    printf '%s\n' "$mark" >&"$tty"
                    _chrome_teeAdd "$pending"
                    pending=""
                    ;;
            esac
            held=0
        else
            _chrome_teeAdd "$pending"
            pending=""
        fi
        _chrome_teePartial "$pending"
    done
    if [[ -n "$pending" ]]; then
        (( held )) && printf '%s' $'\001'"${pending#*$'\001'}" >&"$tty"
        _chrome_teeAdd "$pending"
    fi
    _chrome_teePartial ""
}

_chrome_teePartial() {
    [[ -e "${__CHROME_HIST_PATH:-}" ]] || return 0
    printf '%s' "$1" > "${__CHROME_HIST_PATH}.partial"
}

# ---- parent side --------------------------------------------------------------------------------

# Start the tee. A history file kept by _chrome_histStop keep (suspend) is reused.
# stdout is captured too when it is the terminal, so echo keeps its order with stderr and lands in
# history; a piped stdout is left alone.
_chrome_histStart() {
    local dir
    if [[ -z "${__CHROME_HIST_PATH:-}" || ! -e "$__CHROME_HIST_PATH" ]]; then
        dir="${TMPDIR:-/tmp}"
        if declare -f runtime_getDir &>/dev/null; then
            dir=${ runtime_getDir; } || dir="${TMPDIR:-/tmp}"
        fi
        [[ -n "$dir" ]] || dir="${TMPDIR:-/tmp}"
        __CHROME_HIST_PATH="${dir}/chrome-hist.$$"
        : > "$__CHROME_HIST_PATH" || return 1
        __CHROME_SCROLL=0
    fi
    __CHROME_ACK_PATH="${__CHROME_HIST_PATH}.ack"
    : > "${__CHROME_HIST_PATH}.partial"
    rm -f "$__CHROME_ACK_PATH"
    mkfifo "$__CHROME_ACK_PATH" 2>/dev/null || {
        _chrome_histFiles rm
        return 1
    }
    # Read-write so this open never blocks and the tee's open for write never blocks either.
    exec {__CHROME_ACK}<>"$__CHROME_ACK_PATH" || {
        _chrome_histFiles rm
        return 1
    }
    exec {__CHROME_ERR}>&2
    exec 2> >(_chrome_tee)
    if _chrome_captureStdout; then
        exec {__CHROME_OUT}>&1
        exec 1>&2
    fi
}

# stdout joins the tee only when it is the terminal; a pipe or file stays untouched.
_chrome_captureStdout() {
    [[ -t 1 ]]
}

_chrome_histFiles() {
    [[ -n "${__CHROME_HIST_PATH:-}" ]] || return 0
    rm -f "$__CHROME_HIST_PATH" "${__CHROME_HIST_PATH}.tmp" "${__CHROME_HIST_PATH}.partial" "${__CHROME_HIST_PATH}.ack"
    __CHROME_HIST_PATH=""
    __CHROME_ACK_PATH=""
    __CHROME_SCROLL=0
}

# Flush, restore fd 1/2. "keep" leaves the history file for a later _chrome_histStart (suspend).
_chrome_histStop() {
    local keep="${1:-}"
    _chrome_sync
    if [[ -n "${__CHROME_OUT:-}" ]]; then
        exec 1>&"${__CHROME_OUT}"
        exec {__CHROME_OUT}>&-
        __CHROME_OUT=""
    fi
    if [[ -n "${__CHROME_ERR:-}" ]]; then
        exec 2>&"${__CHROME_ERR}"
        exec {__CHROME_ERR}>&-
        __CHROME_ERR=""
    fi
    if [[ -n "${__CHROME_ACK:-}" ]]; then
        exec {__CHROME_ACK}>&-
        __CHROME_ACK=""
    fi
    if [[ "$keep" == keep ]]; then
        [[ -n "${__CHROME_ACK_PATH:-}" ]] && rm -f "$__CHROME_ACK_PATH"
        __CHROME_ACK_PATH=""
        return 0
    fi
    _chrome_histFiles rm
}

_chrome_ackDrain() {
    local _junk
    while IFS= read -r -t 0 -u "$__CHROME_ACK"; do
        IFS= read -r -t 0.05 -u "$__CHROME_ACK" _junk || break
    done
}

# Send a marker line down fd 2 and wait until the tee has forwarded everything before it.
_chrome_histMark() {
    local _ack
    [[ -n "${__CHROME_ACK:-}" ]] || return 0
    _chrome_ackDrain
    printf '%s\n' "$1" >&2
    IFS= read -r -t 2 -u "$__CHROME_ACK" _ack || true
}

# Wait for the tee. Call before any direct tty paint that must land after prior app output.
_chrome_sync() {
    _chrome_histMark "$__CHROME_MARK_SYNC"
}

# Flush, then record a section boundary: the live view starts here. Older lines stay scrollable.
_chrome_histClear() {
    _chrome_histMark "$__CHROME_MARK_CLEAR"
    __CHROME_SCROLL=0
}

# Body rows minus the cursor row: the row a live console keeps free under the last line.
_chrome_viewHeight() {
    local h=$((__CHROME_BODY_BOT - __CHROME_BODY_TOP))
    (( h < 1 )) && h=1
    printf '%s' "$h"
}

# File → __CHROME_VIEW (lines) + __CHROME_VIEW_BASE (index of the last clear marker).
_chrome_histLoad() {
    local line
    local -a raw=()
    __CHROME_VIEW=()
    __CHROME_VIEW_BASE=0
    [[ -n "${__CHROME_HIST_PATH:-}" && -f "$__CHROME_HIST_PATH" ]] || return 0
    mapfile -t raw < "$__CHROME_HIST_PATH"
    for line in "${raw[@]}"; do
        if [[ "$line" == "$__CHROME_MARK_CLEAR" ]]; then
            __CHROME_VIEW_BASE=${#__CHROME_VIEW[@]}
        else
            __CHROME_VIEW+=("$line")
        fi
    done
}

# First line of the live (offset 0) window. Also the largest valid scroll offset.
_chrome_histLiveStart() {
    local start
    start=$(( ${#__CHROME_VIEW[@]} - ${ _chrome_viewHeight; } ))
    (( start < __CHROME_VIEW_BASE )) && start=$__CHROME_VIEW_BASE
    (( start < 0 )) && start=0
    printf '%s' "$start"
}

# The pending partial line (prompt label, spinner frame) as the tee last saw it, filtered.
_chrome_histPartial() {
    local pend=""
    [[ -n "${__CHROME_HIST_PATH:-}" && -s "${__CHROME_HIST_PATH}.partial" ]] || return 0
    IFS= read -r -d '' pend < "${__CHROME_HIST_PATH}.partial" || true
    [[ -n "$pend" ]] || return 0
    _chrome_histLine "$pend"
    printf '%s' "$__CHROME_FILTERED"
}

# Redraw the body from the history window at __CHROME_SCROLL. Bars are untouched except title
# rows (history indicator). At the live tail the pending partial line is re-emitted on the cursor
# row. Autowrap is off during the paint so a long line clips instead of shifting the view.
_chrome_histRender() {
    local vh live start n row i cur partial=""
    _chrome_histLoad
    n=${#__CHROME_VIEW[@]}
    vh=${ _chrome_viewHeight; }
    live=${ _chrome_histLiveStart; }
    (( __CHROME_SCROLL > live )) && __CHROME_SCROLL=$live
    (( __CHROME_SCROLL < 0 )) && __CHROME_SCROLL=0
    start=$((live - __CHROME_SCROLL))
    row=$__CHROME_BODY_TOP
    _chrome_printf '\033[?7l'
    for ((i = start; i < start + vh && i < n; i++)); do
        _chrome_printf '\033[%d;1H%s\033[0m\033[K' "$row" "${__CHROME_VIEW[i]}"
        row=$((row + 1))
    done
    cur=$row
    for ((; row <= __CHROME_BODY_BOT; row++)); do
        _chrome_printf '\033[%d;1H\033[K' "$row"
    done
    (( cur > __CHROME_BODY_BOT )) && cur=$__CHROME_BODY_BOT
    _chrome_printf '\033[%d;1H' "$cur"
    if (( __CHROME_SCROLL == 0 )); then
        partial=${ _chrome_histPartial; }
        [[ -n "$partial" ]] && _chrome_printf '%s\033[0m' "$partial"
    fi
    _chrome_printf '\033[?7h'
    __CHROME_LOG_ROW=$cur
    _chrome_drawTitleRows
}

# Scroll the body history. Bars stay. n defaults to one page (wheel uses 3).
chrome_scrollUp() {
    local n="${1:-}"
    chrome_isOn || return 0
    [[ -n "${__CHROME_HIST_PATH:-}" ]] || return 0
    [[ "$n" =~ ^[1-9][0-9]*$ ]] || n=${ _chrome_viewHeight; }
    _chrome_sync
    __CHROME_SCROLL=$((__CHROME_SCROLL + n))
    _chrome_histRender
}

chrome_scrollDown() {
    local n="${1:-}"
    chrome_isOn || return 0
    [[ -n "${__CHROME_HIST_PATH:-}" ]] || return 0
    [[ "$n" =~ ^[1-9][0-9]*$ ]] || n=${ _chrome_viewHeight; }
    _chrome_sync
    __CHROME_SCROLL=$((__CHROME_SCROLL - n))
    (( __CHROME_SCROLL < 0 )) && __CHROME_SCROLL=0
    _chrome_histRender
}

# Back to the live tail. No-op unless scrolled. Prompt calls it when a session ends.
chrome_follow() {
    chrome_isOn || return 0
    (( ${__CHROME_SCROLL:-0} > 0 )) || return 0
    _chrome_sync
    __CHROME_SCROLL=0
    _chrome_histRender
}
