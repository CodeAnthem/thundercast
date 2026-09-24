#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Chrome - Layout
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-21 | Modified: 2026-09-24
# Description:   Terminal size, body region, colours, and cursor and erase primitives.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

# Paints go to the tty fd saved at begin so the fd-2 hist tee does not record them.
# Off (no saved fd, no tty): stderr — that is what the suite captures.
# shellcheck disable=SC2059
_chrome_printf() {
    if [[ -n "${__CHROME_TTY:-}" ]]; then
        printf "$@" >&"$__CHROME_TTY"
        return 0
    fi
    { printf "$@" >/dev/tty; } 2>/dev/null || printf "$@" >&2
}

# stty size, not $COLUMNS: bash only refreshes COLUMNS in interactive shells after a child exits.
_chrome_termSize() {
    local sz
    sz=${ { stty size; } 2>/dev/null </dev/tty || true; }
    __CHROME_LINES="${sz%% *}"
    __CHROME_COLS="${sz##* }"
    [[ "$__CHROME_LINES" =~ ^[1-9][0-9]*$ ]] || __CHROME_LINES=24
    [[ "$__CHROME_COLS" =~ ^[1-9][0-9]*$ ]] || __CHROME_COLS=80
    (( __CHROME_LINES >= 6 )) || __CHROME_LINES=6
    (( __CHROME_COLS >= 20 )) || __CHROME_COLS=20
    _chrome_layoutRows
}

# Effective row counts: the body keeps at least 3 rows. Footer gives way first, then header.
_chrome_layoutRows() {
    local avail=$(( __CHROME_LINES - 3 )) hs="${__CHROME_HEADER_ROWS:-2}" fs="${__CHROME_FOOTER_ROWS:-1}"
    (( hs > avail )) && hs=$avail
    (( hs + fs > avail )) && fs=$(( avail - hs ))
    (( fs < 0 )) && fs=0
    __CHROME_HEADER_SHOW=$hs
    __CHROME_FOOTER_SHOW=$fs
    __CHROME_BODY_TOP=$(( hs + 1 ))
    __CHROME_BODY_BOT=$(( __CHROME_LINES - fs ))
}

# Screen row of header row i / footer row i (1-based screen rows). Empty when not shown.
_chrome_rowScreen() {
    local which="$1" i="$2"
    if [[ "$which" == header ]]; then
        (( i < __CHROME_HEADER_SHOW )) || return 0
        printf '%s' $(( i + 1 ))
    else
        (( i < __CHROME_FOOTER_SHOW )) || return 0
        printf '%s' $(( __CHROME_LINES - __CHROME_FOOTER_SHOW + 1 + i ))
    fi
}

# Colour → 0-255, "r" for reverse/default, "" for invalid.
_chrome_colorIndex() {
    case "${1,,}" in
        ''|reverse|default) printf r ;;
        black) printf 0 ;;
        red) printf 1 ;;
        green) printf 2 ;;
        yellow) printf 3 ;;
        blue) printf 4 ;;
        magenta) printf 5 ;;
        cyan) printf 6 ;;
        white) printf 7 ;;
        *)
            if [[ "$1" =~ ^[0-9]{1,3}$ ]] && (( 10#$1 <= 255 )); then
                printf '%s' $((10#$1))
            else
                printf r
            fi
            ;;
    esac
}

# SGR for a bar: reverse when neither colour is set (works without colour support).
_chrome_sgr() {
    local fg bg out=""
    fg=${ _chrome_colorIndex "${1:-}"; }
    bg=${ _chrome_colorIndex "${2:-}"; }
    if [[ "$fg" == r && "$bg" == r ]]; then
        printf '\033[7m'
        return 0
    fi
    if [[ "$fg" != r ]]; then
        if (( fg < 8 )); then out+="3${fg}"
        elif (( fg < 16 )); then out+="9$((fg - 8))"
        else out+="38;5;${fg}"
        fi
    fi
    if [[ "$bg" != r ]]; then
        [[ -n "$out" ]] && out+=";"
        if (( bg < 8 )); then out+="4${bg}"
        elif (( bg < 16 )); then out+="10$((bg - 8))"
        else out+="48;5;${bg}"
        fi
    fi
    printf '\033[%sm' "$out"
}

# Pad or clip text to exactly <width> characters.
_chrome_fit() {
    local text="$1" width="$2" pad
    if (( ${#text} > width )); then
        printf '%s' "${text:0:width}"
    else
        printf -v pad '%*s' "$(( width - ${#text} ))" ''
        printf '%s%s' "$text" "$pad"
    fi
}

# DECSTBM pins rows outside top..bot. It also homes the cursor — save/restore
# so the next write does not land on the title.
_chrome_region() {
    _chrome_printf '\0337\033[%d;%dr\0338' "$__CHROME_BODY_TOP" "$__CHROME_BODY_BOT"
}

_chrome_parkHome() {
    __CHROME_LOG_ROW=$__CHROME_BODY_TOP
    _chrome_printf '\033[%d;1H' "$__CHROME_BODY_TOP"
}

_chrome_clampRow() {
    local row="$1"
    (( row < __CHROME_BODY_TOP )) && row=$__CHROME_BODY_TOP
    (( row > __CHROME_BODY_BOT )) && row=$__CHROME_BODY_BOT
    printf '%s' "$row"
}

# CPR: ESC [ row ; col R. The reply must be read raw — a cooked tty would hold it until Enter and
# hand it to the next prompt. Flush the tee first so the row is the one the app is really on.
# No reply → the last row chrome parked at.
_chrome_cursorRow() {
    local buf="" row="" saved=""
    _chrome_sync
    saved=${ { stty -g; } 2>/dev/null </dev/tty || true; }
    if [[ -n "$saved" ]]; then
        stty -echo -icanon min 0 time 3 </dev/tty 2>/dev/null || true
        _chrome_printf '\033[6n'
        { IFS= read -r -s -d R -t 0.3 buf </dev/tty; } 2>/dev/null || true
        stty "$saved" </dev/tty 2>/dev/null || true
    fi
    if [[ -n "$buf" ]]; then
        row="${buf##*[}"
        row="${row%%;*}"
    fi
    if [[ "$row" =~ ^[1-9][0-9]*$ ]]; then
        printf '%s' "$row"
        return 0
    fi
    printf '%s' "${__CHROME_LOG_ROW:-$__CHROME_BODY_TOP}"
}

_chrome_clearRange() {
    local i start="$1" stop="$2"
    for ((i = start; i <= stop; i++)); do
        _chrome_printf '\033[%d;1H\033[K' "$i"
    done
}

_chrome_clearBody() {
    _chrome_clearRange "$__CHROME_BODY_TOP" "$__CHROME_BODY_BOT"
}

# Full repaint: wipe the alt screen (a resize can smear bar colours into the body), bars, region,
# body from history including the pending partial line. The only 2J while on.
_chrome_redraw() {
    _chrome_sync
    _chrome_termSize
    _chrome_printf '\033[2J\033[H'
    _chrome_drawBars
    _chrome_region
    _chrome_histRender
}
