#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Chrome - Bars
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-21 | Modified: 2026-09-21
# ==================================================================================================
#
# Header and footer are lists of rows. Each row has a type and props, stored in one associative
# array per bar with "<i>.<prop>" keys. Row types: title text sep spacer progress hint.
#
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

declare -g __CHROME_HINT_SEP=$'\037'

_chrome_barsInit() {
    declare -gA __CHROME_HEADER=()
    declare -gA __CHROME_FOOTER=()
    __CHROME_HEADER[0.type]=title
    __CHROME_HEADER[1.type]=text
    __CHROME_HEADER[1.text]=""
    __CHROME_FOOTER[0.type]=text
    __CHROME_FOOTER[0.text]=""
}

_chrome_barName() {
    case "$1" in
        header) printf __CHROME_HEADER ;;
        footer) printf __CHROME_FOOTER ;;
        *) return 1 ;;
    esac
}

_chrome_barRows() {
    if [[ "$1" == header ]]; then
        printf '%s' "$__CHROME_HEADER_ROWS"
    else
        printf '%s' "$__CHROME_FOOTER_ROWS"
    fi
}

# ---- row text (exactly __CHROME_COLS characters) ------------------------------------------------

# <text> aligned inside width minus the right slot, then the right slot.
_chrome_compose() {
    local width="$1" text="$2" align="${3:-left}" right="${4:-}" main pad left_pad
    if [[ -n "$right" ]]; then
        (( ${#right} > width - 1 )) && right="${right:0:width-1}"
        main=$(( width - ${#right} - 1 ))
    else
        main=$width
    fi
    (( ${#text} > main )) && text="${text:0:main}"
    case "$align" in
        center)
            left_pad=$(( (main - ${#text}) / 2 ))
            printf -v pad '%*s' "$left_pad" ''
            text="${pad}${text}"
            ;;
        right)
            printf -v pad '%*s' "$(( main - ${#text} ))" ''
            text="${pad}${text}"
            ;;
    esac
    printf -v pad '%*s' "$(( main - ${#text} ))" ''
    if [[ -n "$right" ]]; then
        printf '%s%s %s' "$text" "$pad" "$right"
    else
        printf '%s%s' "$text" "$pad"
    fi
}

# Items spread evenly across width; too wide → two spaces apart, clipped.
_chrome_spread() {
    local width="$1" total=0 n=0 gap rem item out="" i pad
    local -a items=()
    IFS="$__CHROME_HINT_SEP" read -r -a items <<< "$2"
    for item in "${items[@]}"; do
        [[ -n "$item" ]] || continue
        total=$(( total + ${#item} ))
        n=$(( n + 1 ))
    done
    if (( n <= 1 || total + 2 * (n - 1) > width )); then
        for item in "${items[@]}"; do
            [[ -n "$item" ]] || continue
            out+="${out:+  }${item}"
        done
        _chrome_fit "$out" "$width"
        return 0
    fi
    gap=$(( (width - total) / (n - 1) ))
    rem=$(( (width - total) - gap * (n - 1) ))
    i=0
    for item in "${items[@]}"; do
        [[ -n "$item" ]] || continue
        out+="$item"
        i=$(( i + 1 ))
        (( i < n )) || break
        printf -v pad '%*s' "$(( gap + (i <= rem ? 1 : 0) ))" ''
        out+="$pad"
    done
    _chrome_fit "$out" "$width"
}

_chrome_titleText() {
    local name="Script" version=""
    if declare -f scriptInfo_get_name &>/dev/null; then
        name=${ scriptInfo_get_name; }
        version=${ scriptInfo_get_version; }
    fi
    printf '%s  v%s' "$name" "$version"
}

_chrome_rowText() {
    local which="$1" i="$2" type text right="" ch out
    local bar_name
    bar_name=${ _chrome_barName "$which"; }
    local -n _chrome_bar="$bar_name"
    type="${_chrome_bar[$i.type]:-text}"
    text="${_chrome_bar[$i.text]:-}"
    case "$type" in
        title)
            (( ${__CHROME_SCROLL:-0} > 0 )) && right="[history -${__CHROME_SCROLL}]"
            _chrome_compose "$__CHROME_COLS" "${ _chrome_titleText; }" "${_chrome_bar[$i.align]:-left}" "${_chrome_bar[$i.right]:-$right}"
            ;;
        sep)
            ch="${_chrome_bar[$i.char]:--}"
            ch="${ch:0:1}"
            printf -v out '%*s' "$__CHROME_COLS" ''
            printf '%s' "${out// /"$ch"}"
            ;;
        spacer)
            printf '%*s' "$__CHROME_COLS" ''
            ;;
        progress)
            if declare -f progress_render &>/dev/null; then
                progress_render -c "${_chrome_bar[$i.val]:-0}" "${_chrome_bar[$i.max]:-100}" "$__CHROME_COLS" "$text"
            else
                _chrome_fit "${text:+$text }${_chrome_bar[$i.val]:-0}/${_chrome_bar[$i.max]:-100}" "$__CHROME_COLS"
            fi
            ;;
        hint)
            _chrome_spread "$__CHROME_COLS" "$text"
            ;;
        *)
            _chrome_compose "$__CHROME_COLS" "$text" "${_chrome_bar[$i.align]:-left}" "${_chrome_bar[$i.right]:-}"
            ;;
    esac
}

_chrome_rowSgr() {
    local which="$1" i="$2" fg bg
    local bar_name
    bar_name=${ _chrome_barName "$which"; }
    local -n _chrome_bar="$bar_name"
    if [[ "$which" == header ]]; then
        fg="${_chrome_bar[$i.fg]:-$__CHROME_HEADER_FG}"
        bg="${_chrome_bar[$i.bg]:-$__CHROME_HEADER_BG}"
    else
        fg="${_chrome_bar[$i.fg]:-$__CHROME_FOOTER_FG}"
        bg="${_chrome_bar[$i.bg]:-$__CHROME_FOOTER_BG}"
    fi
    _chrome_sgr "$fg" "$bg"
}

# ---- paint --------------------------------------------------------------------------------------

# One row, body cursor untouched (DECSC/DECRC). Caller syncs.
_chrome_drawRow() {
    local which="$1" i="$2" screen
    screen=${ _chrome_rowScreen "$which" "$i"; }
    [[ -n "$screen" ]] || return 0
    _chrome_printf '\0337\033[%d;1H%s%s\033[0m\0338' "$screen" "${ _chrome_rowSgr "$which" "$i"; }" "${ _chrome_rowText "$which" "$i"; }"
}

_chrome_drawBar() {
    local which="$1" i n
    if [[ "$which" == header ]]; then n=$__CHROME_HEADER_SHOW; else n=$__CHROME_FOOTER_SHOW; fi
    for ((i = 0; i < n; i++)); do
        _chrome_drawRow "$which" "$i"
    done
}

_chrome_drawBars() {
    _chrome_drawBar header
    _chrome_drawBar footer
}

# Title rows carry the history indicator; repaint them when the scroll offset changes.
_chrome_drawTitleRows() {
    local which i n bar_name
    for which in header footer; do
        bar_name=${ _chrome_barName "$which"; }
        local -n _chrome_bar="$bar_name"
        if [[ "$which" == header ]]; then n=$__CHROME_HEADER_SHOW; else n=$__CHROME_FOOTER_SHOW; fi
        for ((i = 0; i < n; i++)); do
            [[ "${_chrome_bar[$i.type]:-}" == title ]] && _chrome_drawRow "$which" "$i"
        done
        unset -n _chrome_bar
    done
}

# ---- public -------------------------------------------------------------------------------------

# chrome_setHeader <i> [-t type] [-f fg] [-b bg] [-a left|center|right] [-r right-text]
#                      [-c char] [-v value] [-m max] [--] [text ...]
# hint: each remaining arg is one item. Others: args joined with spaces.
_chrome_setRow() {
    local which="$1" i="${2:-}" rows type="" fg="" bg="" align="" right="" ch="" val="" max="" text item
    local -a words=()
    shift 2
    rows=${ _chrome_barRows "$which"; }
    if ! [[ "$i" =~ ^[0-9]+$ ]] || (( i >= rows )); then
        error "chrome: ${which} row ${i:-?} out of range (rows: ${rows})"
        return 1
    fi
    # Options may sit before or after the text. "--" ends option parsing.
    while (( $# > 0 )); do
        case "$1" in
            -t) type="${2:-}" ;;
            -f) fg="${2:-}" ;;
            -b) bg="${2:-}" ;;
            -a) align="${2:-}" ;;
            -r) right="${2:-}" ;;
            -c) ch="${2:-}" ;;
            -v) val="${2:-}" ;;
            -m) max="${2:-}" ;;
            --)
                shift
                words+=("$@")
                break
                ;;
            -?)
                error "chrome: unknown row option: $1"
                return 1
                ;;
            *)
                words+=("$1")
                shift
                continue
                ;;
        esac
        shift $(( $# >= 2 ? 2 : 1 ))
    done
    set -- "${words[@]}"
    local bar_name
    bar_name=${ _chrome_barName "$which"; }
    local -n _chrome_bar="$bar_name"
    case "$type" in
        ''|title|text|sep|spacer|progress|hint) ;;
        *) error "chrome: unknown row type: ${type}"; return 1 ;;
    esac
    [[ -n "$type" ]] && _chrome_bar[$i.type]="$type"
    type="${_chrome_bar[$i.type]:-text}"
    if [[ -n "$align" ]]; then
        case "$align" in
            left|center|right) _chrome_bar[$i.align]="$align" ;;
            *) error "chrome: bad alignment: ${align}"; return 1 ;;
        esac
    fi
    if [[ -n "$val" ]]; then
        [[ "$val" =~ ^-?[0-9]+$ ]] || { error "chrome: -v must be a number: ${val}"; return 1; }
        _chrome_bar[$i.val]="$val"
    fi
    if [[ -n "$max" ]]; then
        [[ "$max" =~ ^[0-9]+$ ]] || { error "chrome: -m must be a number: ${max}"; return 1; }
        _chrome_bar[$i.max]="$max"
    fi
    [[ -n "$fg" ]] && _chrome_bar[$i.fg]="$fg"
    [[ -n "$bg" ]] && _chrome_bar[$i.bg]="$bg"
    [[ -n "$right" ]] && _chrome_bar[$i.right]="$right"
    [[ -n "$ch" ]] && _chrome_bar[$i.char]="$ch"
    if (( $# > 0 )); then
        if [[ "$type" == hint ]]; then
            text=""
            for item in "$@"; do
                text+="${text:+$__CHROME_HINT_SEP}${item}"
            done
        else
            text="$*"
        fi
        _chrome_bar[$i.text]="$text"
    fi
    chrome_isOn || return 0
    _chrome_sync
    _chrome_drawRow "$which" "$i"
}

chrome_setHeader() {
    _chrome_setRow header "$@"
}

chrome_setFooter() {
    _chrome_setRow footer "$@"
}

# Header row 1 text. Short for chrome_setHeader 1 -- "<text>".
chrome_setSubtitle() {
    (( ${__CHROME_HEADER_ROWS:-0} > 1 )) || return 0
    _chrome_setRow header 1 -- "${1:-}"
}

# Change the row count. While on this is a full redraw (body from history).
_chrome_setRows() {
    local which="$1" n="${2:-}"
    if ! [[ "$n" =~ ^[0-9]+$ ]] || (( n > 20 )); then
        error "chrome: ${which} rows must be 0-20: ${n:-?}"
        return 1
    fi
    if [[ "$which" == header ]]; then
        __CHROME_HEADER_ROWS=$n
    else
        __CHROME_FOOTER_ROWS=$n
    fi
    chrome_isOn || return 0
    _chrome_redraw
}

chrome_setHeaderRows() {
    _chrome_setRows header "$@"
}

chrome_setFooterRows() {
    _chrome_setRows footer "$@"
}

chrome_getHeaderRows() {
    printf '%s' "${__CHROME_HEADER_ROWS:-0}"
}

chrome_getFooterRows() {
    printf '%s' "${__CHROME_FOOTER_ROWS:-0}"
}
