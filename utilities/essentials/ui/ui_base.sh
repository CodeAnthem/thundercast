#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - UI - Base
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-17 | Modified: 2026-09-18
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_ui_baseDetect() {
    local mode="${__UI_MODE:-auto}" colors=0
    __UI_COLOR=false
    __UI_WARN_CODE=33
    if command -v tput &>/dev/null; then
        colors=${ tput colors 2>/dev/null; } || colors=0
        [[ "$colors" =~ ^[0-9]+$ ]] || colors=0
    fi
    if [[ "$mode" == auto ]]; then
        if [[ ! -t 2 || "${TERM:-}" == dumb || -n "${NO_COLOR:-}" ]]; then
            mode=plain
        elif (( colors >= 8 )); then
            mode=color
        else
            mode=plain
        fi
    elif [[ "$mode" == unicode ]]; then
        if [[ ! -t 2 || "${TERM:-}" == dumb ]]; then
            mode=plain
        else
            mode=color
        fi
    fi
    if [[ "$mode" != plain && -z "${NO_COLOR:-}" ]] && (( colors >= 8 )); then
        __UI_COLOR=true
        (( colors >= 256 )) && __UI_WARN_CODE='38;5;208'
    fi
    __UI_MODE=$mode
}

_ui_err() {
    echo "[ERROR] - [UI] - $1" >&2
}

# Widen H/B/I indents. Pair with ui_indentPop.
ui_indentPush() {
    local extra="${1:-  }"
    __UI_INDENT_STACK+=("${__UI_INDENT_H}"$'\x1f'"${__UI_INDENT_B}"$'\x1f'"${__UI_INDENT_I}")
    __UI_INDENT_H="${extra}${__UI_INDENT_H}"
    __UI_INDENT_B="${extra}${__UI_INDENT_B}"
    __UI_INDENT_I="${extra}${__UI_INDENT_I}"
}

# Restore indents from the last ui_indentPush.
ui_indentPop() {
    local saved h b i
    [[ ${#__UI_INDENT_STACK[@]} -gt 0 ]] || return 0
    saved="${__UI_INDENT_STACK[-1]}"
    unset '__UI_INDENT_STACK[-1]'
    h="${saved%%$'\x1f'*}"
    saved="${saved#*$'\x1f'}"
    b="${saved%%$'\x1f'*}"
    i="${saved#*$'\x1f'}"
    __UI_INDENT_H="$h"
    __UI_INDENT_B="$b"
    __UI_INDENT_I="$i"
}

# Print a heading line.
ui_h() {
    printf '%s%s\n' "$__UI_INDENT_H" "${1:-}" >&2
}

# Print a body line.
ui_b() {
    printf '%s%s\n' "$__UI_INDENT_B" "${1:-}" >&2
}

# Print an inner line.
ui_i() {
    printf '%s%s\n' "$__UI_INDENT_I" "${1:-}" >&2
}

# Print a body warning (orange when color is on).
ui_warn() {
    if [[ "${__UI_COLOR}" == true ]]; then
        printf '%s\033[%sm%s\033[0m\n' "$__UI_INDENT_B" "$__UI_WARN_CODE" "${1:-}" >&2
    else
        printf '%s%s\n' "$__UI_INDENT_B" "${1:-}" >&2
    fi
}

# Print yes/no (no newline). Other values print as-is.
ui_formatBool() {
    local value="$1" text
    case "$value" in
        true) text=yes ;;
        false) text=no ;;
        *) printf '%s' "$value"; return 0 ;;
    esac
    if [[ "${__UI_COLOR}" == true ]]; then
        if [[ "$value" == true ]]; then
            printf '\033[32m%s\033[0m' "$text"
        else
            printf '\033[90m%s\033[0m' "$text"
        fi
        return 0
    fi
    printf '%s' "$text"
}

# Print a label:value row at inner indent.
ui_kv() {
    local label="$1" value="$2" width="${3:-$__UI_LABEL_WIDTH}"
    [[ "$width" =~ ^[0-9]+$ ]] || width="${__UI_LABEL_WIDTH}"
    if [[ "${__UI_COLOR}" == true ]]; then
        printf "%s\033[1m%-${width}s\033[0m %s\n" "$__UI_INDENT_I" "${label}:" "$value" >&2
    else
        printf "%s%-${width}s %s\n" "$__UI_INDENT_I" "${label}:" "$value" >&2
    fi
}

# Print a numbered menu choice row.
ui_choiceRow() {
    ui_kv "${1}) ${2}" "${3:-}" "${4:-26}"
}

# Print numbered rows from an array. Second arg true adds 0) Back.
ui_printMenu() {
    local -n _ui_menu=$1
    local allow_back="${2:-false}" item i=0
    for item in "${_ui_menu[@]}"; do
        i=$((i + 1))
        ui_choiceRow "$i" "$item" ""
    done
    [[ "$allow_back" == true ]] && ui_choiceRow 0 "Back" ""
}
