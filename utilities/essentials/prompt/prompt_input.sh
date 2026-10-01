#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Prompt - Input
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-18 | Modified: 2026-09-24
# Description:   Line, hidden-line, and single-key reads for a prompt.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

# Session map __PROMPT is assigned by _ui_promptReset / prompt() in prompt.sh.
# shellcheck disable=SC2153,SC2154

_ui_promptSessionBegin() {
    local preset="${1:-cbreak}"
    tty_begin
    tty_setPreset "$preset" || {
        tty_end
        return 1
    }
    if declare -f chrome_isOn &>/dev/null && chrome_isOn; then
        chrome_repin || true
        # Cooked reads would take SGR mouse reports as typed text.
        case "$preset" in
            cooked|hidden) chrome_setMouse off || true ;;
        esac
    fi
}

# Confirm: y/n plus bound keys. Enter/backspace already pass _tty_charAllowed.
# Invalid keys stay in tty_getc — they never become tokens (and never look like Enter).
# Select stays cbreak: arrows are ESC sequences and allow is per-byte.
_ui_promptConfirmAllow() {
    local keys="ynYN" k
    for k in "${!__UI_PROMPT_BIND[@]}"; do
        case "$k" in
            enter|esc|backspace|up|down|left|right) ;;
            space) keys+=" " ;;
            ?) keys+="$k" ;;
        esac
    done
    keys+=$'\e'
    tty_allow -a "$keys"
}

_ui_promptSessionEnd() {
    printf '\033[?25h' >&2
    if [[ "${__UI_PROMPT_BRACKET:-}" == 1 ]]; then
        printf '\033[?2004l' >&2
        __UI_PROMPT_BRACKET=0
    fi
    tty_end
    if declare -f chrome_isOn &>/dev/null && chrome_isOn; then
        chrome_setMouse on || true
        chrome_follow || true
    fi
}

# Text fields ask the terminal to wrap a paste, and they drop mouse reports so a click-paste is text.
_ui_promptTextReady() {
    printf '\033[?2004h' >&2
    __UI_PROMPT_BRACKET=1
    if declare -f chrome_setMouse >/dev/null; then
        chrome_setMouse off || true
    fi
}

# A paste is one burst. A zero-timeout check can miss the next byte and treat the Esc as cancel.
_ui_promptEscPending() {
    tty_pending && return 0
    sleep 0.03
    tty_pending
}

_ui_promptReadEsc() {
    local _ui_dest="$1" a="" ch="" rest=""
    if ! _ui_promptEscPending; then
        printf -v "$_ui_dest" '%s' esc
        return 0
    fi
    a=""
    if ! tty_getc a raw; then
        printf -v "$_ui_dest" '%s' esc
        return 0
    fi
    if [[ "$a" != '[' ]]; then
        printf -v "$_ui_dest" '%s' esc
        return 0
    fi
    if ! _ui_promptEscPending; then
        printf -v "$_ui_dest" '%s' esc
        return 0
    fi
    rest=""
    while true; do
        ch=""
        if ! tty_getc ch raw; then
            break
        fi
        rest+="$ch"
        [[ "$ch" == [@-~] ]] && break
        _ui_promptEscPending || break
    done
    case "$rest" in
        A) printf -v "$_ui_dest" '%s' up ;;
        B) printf -v "$_ui_dest" '%s' down ;;
        C) printf -v "$_ui_dest" '%s' right ;;
        D) printf -v "$_ui_dest" '%s' left ;;
        5~|5\;*~) printf -v "$_ui_dest" '%s' pageup ;;
        6~|6\;*~) printf -v "$_ui_dest" '%s' pagedown ;;
        H|1~|7~|1\;*H) printf -v "$_ui_dest" '%s' home ;;
        F|4~|8~|1\;*F) printf -v "$_ui_dest" '%s' end ;;
        \<64\;*M|\<64\;*m) printf -v "$_ui_dest" '%s' wheelup ;;
        \<65\;*M|\<65\;*m) printf -v "$_ui_dest" '%s' wheeldn ;;
        200~) printf -v "$_ui_dest" '%s' brpaste ;;
        201~) printf -v "$_ui_dest" '%s' endpaste ;;
        *) printf -v "$_ui_dest" '%s' ignore ;;
    esac
}

# Throw away the rest of a bracketed paste. Used when the prompt cannot accept it.
_ui_promptDrainBracket() {
    local ch="" token=""
    while true; do
        if ! _ui_promptEscPending; then
            return 0
        fi
        ch=""
        tty_getc ch raw || return 0
        if [[ "$ch" == $'\e' ]]; then
            token=""
            _ui_promptReadEsc token
            [[ "$token" == endpaste ]] && return 0
        fi
    done
}

# Body of a bracketed paste into <var>. Sets <nlvar> to 1 when the paste included a newline.
_ui_promptCollectPaste() {
    local _ui_dest="$1" _ui_nl="$2" ch="" token="" body=""
    printf -v "$_ui_nl" '%s' 0
    while true; do
        if ! _ui_promptEscPending; then
            break
        fi
        ch=""
        tty_getc ch raw || break
        if [[ "$ch" == $'\e' ]]; then
            token=""
            _ui_promptReadEsc token
            [[ "$token" == endpaste ]] && break
            continue
        fi
        case "$ch" in
            $'\r') continue ;;
            $'\n')
                printf -v "$_ui_nl" '%s' 1
                _ui_promptDrainBracket
                break
                ;;
            [[:cntrl:]]) continue ;;
        esac
        body+="$ch"
        if (( ${#body} >= 8192 )); then
            _ui_promptDrainBracket
            break
        fi
    done
    printf -v "$_ui_dest" '%s' "$body"
}

# One token into <var>: char, enter, esc, up, down, left, right, pageup, pagedown, home, end,
# wheelup, wheeldn, ignore, backspace, space, paste, or eof (rc 1).
# mode=one rejects leftover typeahead as paste. mode=edit keeps extra bytes for the next read.
_ui_promptGetKey() {
    local _ui_dest="$1" mode="${2:-one}" ch=""
    [[ -n "$_ui_dest" ]] || return 1
    ch=""
    if ! tty_getc ch; then
        return 1
    fi
    if [[ "$ch" == $'\e' ]]; then
        _ui_promptReadEsc "$_ui_dest"
        if [[ "$mode" == one ]]; then
            local -n _ui_token="$_ui_dest"
            if [[ "$_ui_token" == brpaste ]]; then
                _ui_promptDrainBracket
                _ui_token=paste
            fi
        fi
        return 0
    fi
    if [[ "$mode" == one ]] && tty_pending; then
        tty_drain
        printf -v "$_ui_dest" '%s' paste
        return 0
    fi
    if [[ -z "$ch" || "$ch" == $'\n' || "$ch" == $'\r' ]]; then
        printf -v "$_ui_dest" '%s' enter
        return 0
    fi
    if [[ "$ch" == $'\b' || "$ch" == $'\177' ]]; then
        printf -v "$_ui_dest" '%s' backspace
        return 0
    fi
    if [[ "$ch" == ' ' ]]; then
        printf -v "$_ui_dest" '%s' space
        return 0
    fi
    printf -v "$_ui_dest" '%s' "$ch"
}

_ui_promptChromeScroll() {
    declare -f chrome_isOn &>/dev/null && chrome_isOn || return 0
    case "$1" in
        pageup) chrome_scrollUp ;;
        pagedown) chrome_scrollDown ;;
        wheelup) chrome_scrollUp 3 ;;
        wheeldn) chrome_scrollDown 3 ;;
        home) chrome_scrollUp 1000000 ;;
        end) chrome_follow ;;
    esac
}

_ui_promptRejectPaste() {
    printf '\n' >&2
    ui_b "Paste is not supported — type one key."
}

_ui_promptShowHelp() {
    local token=""
    [[ -n "${__PROMPT[help]}" ]] || return 0
    printf '\n' >&2
    ui_i "${__PROMPT[help]}"
    ui_i "Press a key to continue."
    token=""
    _ui_promptGetKey token one || true
    [[ "$token" == paste ]] && tty_drain
}

_ui_promptHead() {
    # shellcheck disable=SC2153
    local label="${__PROMPT[prefix]}${__PROMPT[msg]}${__PROMPT[suffix]}"
    [[ -n "$label" ]] && ui_b "$label"
    [[ -n "${__PROMPT[desc]}" ]] && ui_i "${__PROMPT[desc]}"
}

_ui_promptTextLabel() {
    # shellcheck disable=SC2153
    local label="${__PROMPT[prefix]}${__PROMPT[msg]}${__PROMPT[suffix]}"
    if [[ -n "${__PROMPT[placeholder]}" ]]; then
        label="${label} (${__PROMPT[placeholder]})"
    fi
    if [[ -n "${__PROMPT[default]}" ]]; then
        label="${label} [${__PROMPT[default]}]"
    fi
    label="${label}: "
    printf '%s%s' "$__UI_INDENT_B" "$label" >&2
}

_ui_promptPutChar() {
    if [[ "${__PROMPT[hide]}" == true ]]; then
        return 0
    fi
    if [[ -n "${__PROMPT[mask]}" ]]; then
        printf '%s' "${__PROMPT[mask]}" >&2
        return 0
    fi
    printf '%s' "$1" >&2
}

_ui_promptRubout() {
    if [[ "${__PROMPT[hide]}" == true ]]; then
        return 0
    fi
    printf '\b \b' >&2
}

# Line editor on cbreak. dest var gets the line. rc 0 submit, 2 back, 3 cancel, 1 eof.
_ui_promptEditLine() {
    local dest="$1" buf="" token="" action="" i ch piece="" nl=0
    _ui_promptTextLabel
    while true; do
        token=""
        if ! _ui_promptGetKey token edit; then
            printf '\n' >&2
            return 1
        fi
        action=${ _ui_promptBindLookup "$token"; }
        case "$action" in
            submit)
                printf '\n' >&2
                printf -v "$dest" '%s' "$buf"
                return 0
                ;;
            cancel)
                printf '\n' >&2
                printf -v "$dest" '%s' ""
                return 3
                ;;
            back)
                printf '\n' >&2
                printf -v "$dest" '%s' ""
                return 2
                ;;
            help)
                _ui_promptShowHelp
                _ui_promptTextLabel
                for ((i = 0; i < ${#buf}; i++)); do
                    ch="${buf:i:1}"
                    _ui_promptPutChar "$ch"
                done
                continue
                ;;
        esac
        case "$token" in
            enter)
                printf '\n' >&2
                printf -v "$dest" '%s' "$buf"
                return 0
                ;;
            esc)
                printf '\n' >&2
                printf -v "$dest" '%s' ""
                return 3
                ;;
            backspace)
                if [[ -n "$buf" ]]; then
                    buf="${buf%?}"
                    _ui_promptRubout
                fi
                ;;
            space)
                buf+=' '
                _ui_promptPutChar ' '
                ;;
            pageup|pagedown|wheelup|wheeldn|home|end)
                _ui_promptChromeScroll "$token"
                printf '\r\033[K' >&2
                _ui_promptTextLabel
                for ((i = 0; i < ${#buf}; i++)); do
                    ch="${buf:i:1}"
                    _ui_promptPutChar "$ch"
                done
                ;;
            up|down|left|right|ignore) ;;
            brpaste)
                piece=""
                nl=0
                _ui_promptCollectPaste piece nl
                if [[ -n "$piece" ]]; then
                    buf+="$piece"
                    for ((i = 0; i < ${#piece}; i++)); do
                        _ui_promptPutChar "${piece:i:1}"
                    done
                fi
                if [[ "$nl" == 1 ]]; then
                    printf '\n' >&2
                    printf -v "$dest" '%s' "$buf"
                    return 0
                fi
                ;;
            *)
                buf+="$token"
                _ui_promptPutChar "$token"
                ;;
        esac
    done
}

_ui_promptLoadOptions() {
    local name="${__PROMPT[options]}" spec value label desc i
    declare -p "$name" &>/dev/null || {
        error "prompt: --options ${name} is not an array"
        return 1
    }
    local -n _ui_prompt_opts="$name"
    ((${#_ui_prompt_opts[@]} > 0)) || {
        error "prompt: --options ${name} is empty"
        return 1
    }
    __UI_PROMPT_OPT_VALS=()
    __UI_PROMPT_OPT_LABELS=()
    __UI_PROMPT_OPT_DESCS=()
    for spec in "${_ui_prompt_opts[@]}"; do
        value="${spec%%|*}"
        if [[ "$spec" == *'|'* ]]; then
            label="${spec#*|}"
            if [[ "$label" == *'|'* ]]; then
                desc="${label#*|}"
                label="${label%%|*}"
            else
                desc=""
            fi
        else
            label="$value"
            desc=""
        fi
        __UI_PROMPT_OPT_VALS+=("$value")
        __UI_PROMPT_OPT_LABELS+=("$label")
        __UI_PROMPT_OPT_DESCS+=("$desc")
    done
    __PROMPT[cursor]=0
    if [[ -n "${__PROMPT[default]}" ]]; then
        for i in "${!__UI_PROMPT_OPT_VALS[@]}"; do
            if [[ "${__UI_PROMPT_OPT_VALS[i]}" == "${__PROMPT[default]}" || "${__UI_PROMPT_OPT_LABELS[i]}" == "${__PROMPT[default]}" ]]; then
                __PROMPT[cursor]="$i"
                return 0
            fi
        done
        if [[ "${__PROMPT[default]}" =~ ^[1-9][0-9]*$ ]]; then
            i=$((10#${__PROMPT[default]} - 1))
            if ((i >= 0 && i < ${#__UI_PROMPT_OPT_VALS[@]})); then
                __PROMPT[cursor]="$i"
            fi
        fi
    fi
}

_ui_promptDefaultFooter() {
    if [[ -n "${__PROMPT[footer]}" ]]; then
        printf '%s' "${__PROMPT[footer]}"
        return 0
    fi
    case "${__PROMPT[type]}" in
        select)
            if [[ "${__PROMPT[plain]}" == true ]]; then
                printf '%s' "Number + Enter to submit"
            else
                printf '%s' "↑/↓ or 1-9 move   Enter submit   Esc cancel"
            fi
            ;;
        multi-select)
            if [[ "${__PROMPT[plain]}" == true ]]; then
                printf '%s' "Number toggles   empty Enter submits"
            else
                printf '%s' "↑/↓ move   Space/1-9 toggle   Enter submit   Esc cancel"
            fi
            ;;
        confirm)
            printf '%s' "y/n"
            ;;
        *)
            printf '%s' ""
            ;;
    esac
}
