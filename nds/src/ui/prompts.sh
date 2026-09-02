#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI - User prompts and menu input
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2026-08-28
# Description:   Interactive yes/no/back and numbered-menu prompts
# ==================================================================================================

declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_PROMPTS_SKIP

# Description: True when a value is boolean true (true/1, case-insensitive).
nds_env_is_true() {
    nds_lib_env_is_true "$1"
}

# Description: Yes/no/back confirm; skippable via NDS_PROMPTS_SKIP.
nds_ask_user_continue() {
    local prompt="${1:-Do you want to proceed?}"
    local confirm=""

    if nds_skip_menu NDS_PROMPTS_SKIP; then
        printf '%s%s [y/n/b]: y (skipped)\n' "$NDS_UI_INDENT_B" "$prompt" >&2
        return 0
    fi

    while true; do
        nds_ui_tty_read -rsp "${NDS_UI_INDENT_B}${prompt} [y/n/b]: " -n 1 confirm
        case "${confirm,,}" in
            y)
                printf 'Yes\n' >&2
                return 0
                ;;
            n)
                printf 'No\n' >&2
                return 1
                ;;
            b)
                printf 'Back\n' >&2
                return 2
                ;;
            *)
                printf '\n' >&2
                nds_ui_b "Enter y (yes), n (no), or b (back)"
                ;;
        esac
    done
}

# Description: Yes/no confirm without a back option; skippable via NDS_PROMPTS_SKIP.
# Echoes Yes/No after the keypress so the answer is visible (same as leftover-gh).
# Arguments:
# - prompt:  <String|optional> Question text
# - default: <String|optional> y or n — Enter accepts this; empty means Enter repeats
nds_ask_user_to_proceed() {
    local prompt="${1:-Do you want to proceed?}"
    local default="${2:-}"
    local confirm="" def_tag=""

    case "${default,,}" in
        y|yes|true) default=y; def_tag=" [y]" ;;
        n|no|false) default=n; def_tag=" [n]" ;;
        *) default="" ;;
    esac

    if nds_skip_menu NDS_PROMPTS_SKIP; then
        if [[ "$default" == "n" ]]; then
            printf '%s%s%s (y/n): n (skipped)\n' "$NDS_UI_INDENT_B" "$prompt" "$def_tag" >&2
            return 1
        fi
        printf '%s%s%s (y/n): y (skipped)\n' "$NDS_UI_INDENT_B" "$prompt" "$def_tag" >&2
        return 0
    fi

    while true; do
        nds_ui_tty_read -rsp "${NDS_UI_INDENT_B}${prompt}${def_tag} (y/n): " -n 1 confirm
        case "${confirm,,}" in
            y)
                printf 'Yes\n' >&2
                return 0
                ;;
            n)
                printf 'No\n' >&2
                return 1
                ;;
            "")
                if [[ "$default" == "y" ]]; then
                    printf 'Yes\n' >&2
                    return 0
                elif [[ "$default" == "n" ]]; then
                    printf 'No\n' >&2
                    return 1
                fi
                printf '\n' >&2
                continue
                ;;
            *)
                printf '\n' >&2
                nds_ui_b "Press y (yes) or n (no)"
                ;;
        esac
    done
}

# Description: Build a standardized numbered-menu prompt line.
# Arguments:
# - min:         <Int> Minimum valid digit
# - max:         <Int> Maximum valid digit
# - default_opt: <String|optional> Default shown in brackets
# - text:        <String|optional> Prompt text
# - allow_back:  <Bool|optional> When true, show 0=back
# - allow_x:     <Bool|optional> When true, show x=done
nds_ui_numbered_prompt() {
    local min="$1" max="$2" default_opt="${3:-}" text="${4:-Make your selection}"
    local allow_back="${5:-false}" allow_x="${6:-false}"
    local extra="${min}-${max}"

    nds_ui_init
    [[ "$allow_back" == "true" ]] && extra="${extra}, 0=back"
    [[ "$allow_x" == "true" ]] && extra="${extra}, x=done"
    if [[ -n "$default_opt" ]]; then
        printf '%s%s [%s] (%s): ' "$NDS_UI_INDENT_I" "$text" "$default_opt" "$extra"
    else
        printf '%s%s (%s): ' "$NDS_UI_INDENT_I" "$text" "$extra"
    fi
}

# Description: Read one menu key (no Enter) and echo it, same as y/n Yes/No.
# Do not call from command substitution — TTY read must stay in the current shell.
# Empty Enter returns 1 so the caller can apply a default.
# Arguments:
# - out:        <Nameref> Receives the selected number (or x)
# - prompt:     <String> Prompt text (from nds_ui_numbered_prompt)
# - min:        <Int> Minimum valid number
# - max:        <Int> Maximum valid number
# - allow_back: <Bool|optional> When true, 0 or b stores "0"
# - allow_x:    <Bool|optional> When true, x stores "x"
nds_ui_read_menu_digit() {
    local -n _nds_ui_menu_digit=$1
    local prompt="$2" min="$3" max="$4" allow_back="${5:-false}" allow_x="${6:-false}"
    local _nds_ui_menu_raw="" hint

    nds_ui_init
    if [[ "$allow_back" == "true" && "$allow_x" == "true" ]]; then
        hint="Invalid selection. Choose ${min}-${max}, 0 to go back, or x when done."
    elif [[ "$allow_back" == "true" ]]; then
        hint="Invalid selection. Choose ${min}-${max}, or 0 to go back."
    elif [[ "$allow_x" == "true" ]]; then
        hint="Invalid selection. Choose ${min}-${max}, or x when done."
    else
        hint="Invalid selection. Choose ${min}-${max}."
    fi
    while true; do
        if ! nds_ui_tty_read -rsn1 -p "$prompt" _nds_ui_menu_raw; then
            return 1
        fi
        if [[ -z "$_nds_ui_menu_raw" || "$_nds_ui_menu_raw" == $'\n' || "$_nds_ui_menu_raw" == $'\r' ]]; then
            return 1
        fi
        if [[ "$allow_x" == "true" ]] && [[ "${_nds_ui_menu_raw,,}" == "x" ]]; then
            printf 'x\n' >&2
            _nds_ui_menu_digit=x
            return 0
        fi
        if [[ "$allow_back" == "true" ]] && [[ "$_nds_ui_menu_raw" == "0" \
            || "$_nds_ui_menu_raw" == "b" || "$_nds_ui_menu_raw" == "B" ]]; then
            printf '%s\n' "$_nds_ui_menu_raw" >&2
            _nds_ui_menu_digit=0
            return 0
        fi
        if [[ "$_nds_ui_menu_raw" =~ ^[0-9]$ ]] \
            && (( 10#$_nds_ui_menu_raw >= min && 10#$_nds_ui_menu_raw <= max )); then
            printf '%s\n' "$_nds_ui_menu_raw" >&2
            _nds_ui_menu_digit="$_nds_ui_menu_raw"
            return 0
        fi
        printf '\n' >&2
        nds_ui_b "$hint"
    done
}

_nds_ui_hidden_block_restore() {
    [[ -n "${_NDS_UI_STTY_ORIG:-}" ]] && stty "$_NDS_UI_STTY_ORIG" </dev/tty 2>/dev/null || true
    unset _NDS_UI_STTY_ORIG
}

_nds_ui_hidden_block_abort() {
    _nds_ui_hidden_block_restore
    nds_ui_prompt_leave
    _nds_ui_session_sigint
}

_nds_ui_hidden_block_finish() {
    _nds_ui_hidden_block_restore
    trap _nds_ui_session_sigint SIGINT
    trap - TERM
    nds_ui_prompt_leave
}

# Description: Read a hidden multiline block from the TTY until an end marker.
# Input is not echoed (password-style). Does not write to CONFIG_DATA.
# Git auth paste uses this under NDS_AUTO_CONFIRM when a TTY exists.
# Arguments:
# - prompt: <String|optional> Shown before input
# Returns:
# - <String> Block on stdout (including the END line); non-zero when no TTY or empty
nds_ui_read_hidden_block() {
    local prompt="${1:-Paste the private key (input is hidden)}"
    local line block="" n=0
    local tty="/dev/tty"

    [[ -e "$tty" ]] || return 1

    nds_ui_init
    nds_ui_b "$prompt"
    nds_ui_i "Finish with the -----END ... PRIVATE KEY----- line, or a lone period."

    nds_ui_prompt_enter
    _NDS_UI_STTY_ORIG="$(stty -g <"$tty" 2>/dev/null)" || {
        nds_ui_prompt_leave
        return 1
    }
    trap _nds_ui_hidden_block_abort INT TERM
    stty -echo <"$tty" 2>/dev/null || {
        _nds_ui_hidden_block_finish
        return 1
    }

    while IFS= read -r line || [[ -n "$line" ]]; do
        n=$((n + 1))
        if (( n > 200 )); then
            _nds_ui_hidden_block_finish
            nds_ui_b "Paste too long (stopped after 200 lines)."
            return 1
        fi
        if [[ "$line" == "." ]]; then
            break
        fi
        block+="${line}"$'\n'
        printf '\r\033[K%sreceived %d line(s)' "${NDS_UI_INDENT_B:-  }" "$n" >&2
        [[ "$line" =~ ^-----END\ .*PRIVATE\ KEY-----[[:space:]]*$ ]] && break
    done <"$tty"

    _nds_ui_hidden_block_finish
    printf '\r\033[K' >&2
    if (( n > 0 )); then
        nds_ui_i "Key received (${n} line(s))."
    else
        printf '\n' >&2
    fi

    [[ -n "$block" ]] || return 1
    printf '%s' "$block"
    return 0
}
