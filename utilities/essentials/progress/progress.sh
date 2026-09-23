#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Progress
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-21 | Modified: 2026-09-21
# ==================================================================================================
#
# Progress bar. progress_render is a pure string builder (chrome rows use it); progress_begin /
# progress_set / progress_end draw one CR line on stderr like task does. Does not prompt.
#
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_essentials_progress_init() {
    [[ "${__PROGRESS_INITIALIZED:-false}" == true ]] && return 0

    local -n config="essentials_config"
    declare -g __PROGRESS_FILL="${config[PROGRESS_FILL]:-#}"
    declare -g __PROGRESS_EMPTY="${config[PROGRESS_EMPTY]:--}"
    declare -g __PROGRESS_WIDTH="${config[PROGRESS_WIDTH]:-50}"
    if ! [[ "$__PROGRESS_WIDTH" =~ ^[1-9][0-9]*$ ]] || (( __PROGRESS_WIDTH < 10 )); then
        error "Progress: invalid PROGRESS_WIDTH: ${__PROGRESS_WIDTH}"
        return 1
    fi
    if (( ${#__PROGRESS_FILL} != 1 || ${#__PROGRESS_EMPTY} != 1 )); then
        error "Progress: PROGRESS_FILL / PROGRESS_EMPTY must be one character"
        return 1
    fi

    declare -g __PROGRESS_OPEN=0
    declare -g __PROGRESS_CUR=0
    declare -g __PROGRESS_MAX=0
    declare -g __PROGRESS_LABEL=""
    declare -g __PROGRESS_LAST=""

    if declare -f eventRegister &>/dev/null; then
        eventRegister ui.line.take progress_yield || return 1
    fi

    declare -g __PROGRESS_INITIALIZED=true
}

_progressTty() {
    if declare -f tty_ok &>/dev/null; then
        tty_ok
    else
        [[ -t 2 ]]
    fi
}

# Whole-number percent, clamped. max 0 → 0.
_progress_pct() {
    local cur="$1" max="$2"
    (( max > 0 )) || { printf 0; return 0; }
    (( cur < 0 )) && cur=0
    (( cur > max )) && cur=$max
    printf '%s' $(( cur * 100 / max ))
}

# Print "label [####----] 45%" exactly <width> characters wide (padded, or clipped when the bar
# has no room). -c adds "cur/max" before the percent.
progress_render() {
    local count=0 cur max width label="" pct suffix bar="" fill empty barw pad line
    if [[ "${1:-}" == -c ]]; then
        count=1
        shift
    fi
    cur="${1:-0}"
    max="${2:-0}"
    width="${3:-40}"
    label="${4:-}"
    [[ "$cur" =~ ^-?[0-9]+$ ]] || cur=0
    [[ "$max" =~ ^[0-9]+$ ]] || max=0
    [[ "$width" =~ ^[1-9][0-9]*$ ]] || width=40
    (( cur < 0 )) && cur=0
    (( cur > max )) && cur=$max
    pct=${ _progress_pct "$cur" "$max"; }
    if (( count )); then
        printf -v suffix ' %d/%d %3d%%' "$cur" "$max" "$pct"
    else
        printf -v suffix ' %3d%%' "$pct"
    fi
    [[ -n "$label" ]] && label="${label} "
    barw=$(( width - ${#label} - ${#suffix} - 2 ))
    if (( barw >= 1 )); then
        fill=$(( barw * pct / 100 ))
        empty=$(( barw - fill ))
        printf -v bar '%*s' "$fill" ''
        bar="${bar// /"${__PROGRESS_FILL:-#}"}"
        printf -v pad '%*s' "$empty" ''
        bar="[${bar}${pad// /"${__PROGRESS_EMPTY:--}"}]"
        line="${label}${bar}${suffix}"
    else
        line="${label}${suffix# }"
    fi
    if (( ${#line} > width )); then
        line="${line:0:width}"
    elif (( ${#line} < width )); then
        printf -v pad '%*s' "$(( width - ${#line} ))" ''
        line+="$pad"
    fi
    printf '%s' "$line"
}

progress_isOpen() {
    [[ "${__PROGRESS_OPEN:-0}" == 1 ]]
}

_progress_draw() {
    local line width
    _progressTty || return 0
    width=$(( __PROGRESS_WIDTH - ${#__UI_INDENT_B} ))
    (( width < 10 )) && width=10
    line=${ progress_render -c "$__PROGRESS_CUR" "$__PROGRESS_MAX" "$width" "$__PROGRESS_LABEL"; }
    [[ "$line" == "$__PROGRESS_LAST" ]] && return 0
    __PROGRESS_LAST="$line"
    printf '\r\033[K%s%s' "${__UI_INDENT_B:-  }" "${line%"${line##*[! ]}"}" >&2
}

# Open a bar: progress_begin <max> [label]. Replaces an open one.
progress_begin() {
    local max="${1:-}" label="${2:-}"
    [[ "$max" =~ ^[0-9]+$ ]] || {
        error "progress_begin: max must be a number: ${max}"
        return 1
    }
    __PROGRESS_OPEN=1
    __PROGRESS_CUR=0
    __PROGRESS_MAX="$max"
    __PROGRESS_LABEL="$label"
    __PROGRESS_LAST=""
    _progress_draw
}

# Move the bar: progress_set <cur> [label]. Redraws only when the rendered line changes.
progress_set() {
    local cur="${1:-}"
    progress_isOpen || return 0
    [[ "$cur" =~ ^-?[0-9]+$ ]] || return 0
    __PROGRESS_CUR="$cur"
    (( $# > 1 )) && __PROGRESS_LABEL="$2"
    _progress_draw
}

# Finish at 100 %, newline. Non-TTY prints the final line once.
progress_end() {
    progress_isOpen || return 0
    (( $# > 0 )) && __PROGRESS_LABEL="$1"
    __PROGRESS_CUR="$__PROGRESS_MAX"
    __PROGRESS_LAST=""
    if _progressTty; then
        _progress_draw
        printf '\n' >&2
    else
        printf '%s%s\n' "${__UI_INDENT_B:-  }" "${ progress_render -c "$__PROGRESS_CUR" "$__PROGRESS_MAX" 40 "$__PROGRESS_LABEL"; }" >&2
    fi
    __PROGRESS_OPEN=0
}

# Drop the bar without a final line.
progress_cancel() {
    progress_isOpen || return 0
    _progressTty && printf '\r\033[K' >&2
    __PROGRESS_OPEN=0
    __PROGRESS_LAST=""
}

# ui.line.take: vacate the CR line so a prompt can print. Next progress_set redraws.
progress_yield() {
    progress_isOpen || return 0
    _progressTty || return 0
    printf '\r\033[K' >&2
    __PROGRESS_LAST=""
}

_essentials_progress_init || return 1
