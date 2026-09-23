#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Prompt - Types
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-18 | Modified: 2026-09-23
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_ui_promptNormYesno() {
    case "${1,,}" in
        y|yes|true) printf y ;;
        n|no|false) printf n ;;
        *) printf '%s' "$1" ;;
    esac
}

_ui_promptConfirm() {
    local default token="" tag="y/n" action
    default=${ _ui_promptNormYesno "${__PROMPT[default]}"; }
    [[ "$default" == y || "$default" == n ]] || default=""
    _ui_promptHasAction back && tag="y/n/b"
    if [[ "$default" == y ]]; then
        tag="Y/${tag#y/}"
    elif [[ "$default" == n ]]; then
        tag="${tag/n/N}"
    fi
    [[ -z "${__PROMPT[msg]}" ]] && __PROMPT[msg]="Do you want to proceed?"

    _ui_promptSessionBegin cbreak || return 1
    _ui_promptConfirmAllow || {
        _ui_promptSessionEnd
        return 1
    }
    printf '%s%s [%s]: ' "$__UI_INDENT_B" "${__PROMPT[prefix]}${__PROMPT[msg]}${__PROMPT[suffix]}" "$tag" >&2
    while true; do
        token=""
        if ! _ui_promptGetKey token one; then
            _ui_promptSessionEnd
            _ui_promptEof
            return 4
        fi
        if [[ "$token" == paste ]]; then
            _ui_promptRejectPaste
            printf '%s%s [%s]: ' "$__UI_INDENT_B" "${__PROMPT[prefix]}${__PROMPT[msg]}${__PROMPT[suffix]}" "$tag" >&2
            continue
        fi
        action=${ _ui_promptBindLookup "$token"; }
        case "$action" in
            cancel)
                printf 'Cancel\n' >&2
                _ui_promptSessionEnd
                _ui_promptDone cancel
                return $?
                ;;
            back)
                printf 'Back\n' >&2
                _ui_promptSessionEnd
                _ui_promptDone back
                return $?
                ;;
            help)
                _ui_promptShowHelp
                continue
                ;;
        esac
        case "${token,,}" in
            y)
                printf 'Yes\n' >&2
                _ui_promptSessionEnd
                _ui_promptDone submit y
                return $?
                ;;
            n)
                printf 'No\n' >&2
                _ui_promptSessionEnd
                _ui_promptDone submit n
                return $?
                ;;
            enter)
                if [[ "$default" == y ]]; then
                    printf 'Yes\n' >&2
                    _ui_promptSessionEnd
                    _ui_promptDone submit y
                    return $?
                elif [[ "$default" == n ]]; then
                    printf 'No\n' >&2
                    _ui_promptSessionEnd
                    _ui_promptDone submit n
                    return $?
                fi
                printf '\n' >&2
                printf '%s%s [%s]: ' "$__UI_INDENT_B" "${__PROMPT[prefix]}${__PROMPT[msg]}${__PROMPT[suffix]}" "$tag" >&2
                ;;
            pageup|pagedown|wheelup|wheeldn|home|end)
                # Reprint replaces the pending line (\r): one label on screen and in history.
                _ui_promptChromeScroll "$token"
                printf '\r\033[K%s%s [%s]: ' "$__UI_INDENT_B" "${__PROMPT[prefix]}${__PROMPT[msg]}${__PROMPT[suffix]}" "$tag" >&2
                ;;
            ignore|up|down|left|right)
                ;;
            *)
                printf '\n' >&2
                ui_b "Press y (yes) or n (no)"
                printf '%s%s [%s]: ' "$__UI_INDENT_B" "${__PROMPT[prefix]}${__PROMPT[msg]}${__PROMPT[suffix]}" "$tag" >&2
                ;;
        esac
    done
}

_ui_promptText() {
    local line="" rc
    _ui_promptSessionBegin cbreak || return 1
    while true; do
        line=""
        _ui_promptEditLine line
        rc=$?
        case "$rc" in
            1)
                _ui_promptSessionEnd
                _ui_promptEof
                return 4
                ;;
            2)
                _ui_promptSessionEnd
                _ui_promptDone back
                return $?
                ;;
            3)
                _ui_promptSessionEnd
                _ui_promptDone cancel
                return $?
                ;;
        esac
        if [[ -z "$line" && -n "${__PROMPT[default]}" ]]; then
            line="${__PROMPT[default]}"
        fi
        if [[ -z "$line" && "${__PROMPT[allow_empty]}" != true && -z "${__PROMPT[default]}" ]]; then
            ui_b "A value is required."
            continue
        fi
        _ui_promptSessionEnd
        _ui_promptDone submit "$line"
        return $?
    done
}

_ui_promptMultilineUnhook() {
    if [[ "${__UI_BLOCK_TRAPS:-}" == th ]]; then
        trapUnregister INT _ui_promptMultilineAbort 2>/dev/null || true
        trapUnregister TERM _ui_promptMultilineAbort 2>/dev/null || true
    elif [[ "${__UI_BLOCK_TRAPS:-}" == raw ]]; then
        eval "${__UI_BLOCK_PREV_INT:-trap - INT}"
        eval "${__UI_BLOCK_PREV_TERM:-trap - TERM}"
    fi
    __UI_BLOCK_TRAPS=""
    unset __UI_BLOCK_PREV_INT __UI_BLOCK_PREV_TERM
}

_ui_promptMultilineAbort() {
    printf '\033[?25h' >&2
    tty_end
    [[ "${__UI_BLOCK_TRAPS:-}" == th ]] && return 0
    if declare -f eventRun &>/dev/null && eventHas trap.INT; then
        eventRun trap.INT || true
    fi
    if declare -f tty_restore &>/dev/null; then
        tty_restore
    fi
    printf '\n' >&2
    exit 130
}

_ui_promptMultilineHook() {
    if declare -f trapRegister &>/dev/null; then
        trapRegister INT _ui_promptMultilineAbort 1 || return 1
        if ! trapRegister TERM _ui_promptMultilineAbort 1; then
            trapUnregister INT _ui_promptMultilineAbort 2>/dev/null || true
            return 1
        fi
        __UI_BLOCK_TRAPS=th
        return 0
    fi
    __UI_BLOCK_PREV_INT=${ trap -p INT; }
    __UI_BLOCK_PREV_TERM=${ trap -p TERM; }
    trap _ui_promptMultilineAbort INT TERM
    __UI_BLOCK_TRAPS=raw
}

_ui_promptMultilineFinish() {
    _ui_promptMultilineUnhook
    _ui_promptSessionEnd
}

_ui_promptMultiline() {
    local line="" block="" n=0 preset=cooked eof=false
    [[ "${__PROMPT[hide]}" == true ]] && preset=hidden

    _ui_promptHead
    ui_i "Finish with a line that is exactly: ${__PROMPT[end]}"

    _ui_promptSessionBegin "$preset" || return 1
    _ui_promptMultilineHook || {
        _ui_promptSessionEnd
        return 1
    }
    tty_drain

    while true; do
        line=""
        if ! tty_read -r line; then
            eof=true
            break
        fi
        n=$((n + 1))
        if ((n > 200)); then
            _ui_promptMultilineFinish
            ui_b "Paste too long (stopped after 200 lines)."
            _ui_promptFail
            return 1
        fi
        if [[ "$line" == "${__PROMPT[end]}" ]]; then
            if [[ "${__PROMPT[include_end]}" == true ]]; then
                block+="${line}"$'\n'
            fi
            break
        fi
        block+="${line}"$'\n'
        if [[ "${__PROMPT[hide]}" == true ]]; then
            printf '\r\033[K%sreceived %d line(s)' "$__UI_INDENT_B" "$n" >&2
        fi
    done

    _ui_promptMultilineFinish
    if [[ "${__PROMPT[hide]}" == true ]]; then
        printf '\r\033[K' >&2
        if [[ "$eof" == true ]]; then
            printf '\n' >&2
        elif ((n > 0)); then
            ui_i "Received (${n} line(s))."
        else
            printf '\n' >&2
        fi
    fi
    if [[ "$eof" == true ]]; then
        _ui_promptEof
        return 4
    fi
    if [[ -z "$block" && -n "${__PROMPT[default]}" ]]; then
        block="${__PROMPT[default]}"
    elif [[ -z "$block" && "${__PROMPT[allow_empty]}" != true ]]; then
        _ui_promptFail
        return 1
    fi
    _ui_promptDone submit "$block"
}

_ui_promptKey() {
    local token=""
    [[ -z "${__PROMPT[msg]}" ]] && __PROMPT[msg]="Press a key:"
    _ui_promptSessionBegin cbreak || return 1
    while true; do
        printf '%s%s ' "$__UI_INDENT_B" "${__PROMPT[prefix]}${__PROMPT[msg]}${__PROMPT[suffix]}" >&2
        token=""
        if ! _ui_promptGetKey token one; then
            _ui_promptSessionEnd
            _ui_promptEof
            return 4
        fi
        if [[ "$token" == paste ]]; then
            _ui_promptRejectPaste
            continue
        fi
        printf '\n' >&2
        _ui_promptSessionEnd
        _ui_promptDone submit "$token"
        return $?
    done
}

_ui_promptPause() {
    local discard="" token=""
    [[ "${__UI_NO_PAUSE}" == true ]] && return 0
    [[ -z "${__PROMPT[msg]}" ]] && __PROMPT[msg]="Press Enter to continue"
    if declare -f chrome_isOn &>/dev/null && chrome_isOn; then
        _ui_promptSessionBegin cbreak || return 1
        printf '%s%s ' "$__UI_INDENT_B" "${__PROMPT[msg]}" >&2
        while true; do
            token=""
            if ! _ui_promptGetKey token one; then
                _ui_promptSessionEnd
                _ui_promptEof
                return 4
            fi
            case "$token" in
                enter)
                    printf '\n' >&2
                    _ui_promptSessionEnd
                    _ui_promptDone submit ""
                    return $?
                    ;;
                pageup|pagedown|wheelup|wheeldn|home|end)
                    _ui_promptChromeScroll "$token"
                    printf '\r\033[K%s%s ' "$__UI_INDENT_B" "${__PROMPT[msg]}" >&2
                    ;;
            esac
        done
    fi
    _ui_promptSessionBegin cooked || return 1
    printf '%s%s ' "$__UI_INDENT_B" "${__PROMPT[msg]}" >&2
    tty_read -r discard || true
    _ui_promptSessionEnd
    _ui_promptDone submit ""
}
