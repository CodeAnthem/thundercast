#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI - Terminal capabilities and layout
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-08-18
# Description:   Terminal mode, indentation, columns — no logging, prompts, or banners
# ==================================================================================================

declare -g NDS_UI_MODE=""
declare -g NDS_UI_COLOR=false
declare -g NDS_UI_LABEL_WIDTH=38
declare -g NDS_UI_INDENT_H=' '
declare -g NDS_UI_INDENT_B='  '
declare -g NDS_UI_INDENT_I='    '
declare -ga _NDS_UI_INDENT_STACK=()

readonly NDS_ACTION_BACK=10

# Description: Widen H/B/I indents; pair with nds_ui_indent_pop.
# Arguments:
# - extra: <String|optional> Prefix to prepend (default: two spaces)
nds_ui_indent_push() {
    local extra="${1:-  }"
    _NDS_UI_INDENT_STACK+=("${NDS_UI_INDENT_H}"$'\x1f'"${NDS_UI_INDENT_B}"$'\x1f'"${NDS_UI_INDENT_I}")
    NDS_UI_INDENT_H="${extra}${NDS_UI_INDENT_H}"
    NDS_UI_INDENT_B="${extra}${NDS_UI_INDENT_B}"
    NDS_UI_INDENT_I="${extra}${NDS_UI_INDENT_I}"
}

# Description: Restore indents from the last nds_ui_indent_push.
nds_ui_indent_pop() {
    local saved h b i
    [[ ${#_NDS_UI_INDENT_STACK[@]} -gt 0 ]] || return 0
    saved="${_NDS_UI_INDENT_STACK[-1]}"
    unset '_NDS_UI_INDENT_STACK[-1]'
    h="${saved%%$'\x1f'*}"
    saved="${saved#*$'\x1f'}"
    b="${saved%%$'\x1f'*}"
    i="${saved#*$'\x1f'}"
    NDS_UI_INDENT_H="$h"
    NDS_UI_INDENT_B="$b"
    NDS_UI_INDENT_I="$i"
}

# Description: Print a heading line at heading indent.
nds_ui_h() {
    printf '%s%s\n' "$NDS_UI_INDENT_H" "${1:-}" >&2
}

# Description: Print a body line at body indent.
nds_ui_b() {
    printf '%s%s\n' "$NDS_UI_INDENT_B" "${1:-}" >&2
}

# Description: Print an inner line at inner indent.
nds_ui_i() {
    printf '%s%s\n' "$NDS_UI_INDENT_I" "${1:-}" >&2
}

# Description: Print a body warning in orange (256-color) or yellow.
nds_ui_warn() {
    local code='33'
    nds_ui_init
    if [[ "${NDS_UI_COLOR:-false}" == true ]]; then
        if command -v tput &>/dev/null && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 256 ]]; then
            code='38;5;208'
        fi
        printf '%s\033[%sm%s\033[0m\n' "$NDS_UI_INDENT_B" "$code" "${1:-}" >&2
    else
        printf '%s%s\n' "$NDS_UI_INDENT_B" "${1:-}" >&2
    fi
}

# Description: Detect color/unicode and seed indent strings (once per process).
nds_ui_init() {
    [[ -n "${NDS_UI_INIT_DONE:-}" ]] && return 0
    NDS_UI_INIT_DONE=1

    local mode="${NDS_UI_MODE:-auto}"
    NDS_UI_COLOR=false

    if [[ "$mode" == "auto" ]]; then
        if [[ ! -t 2 ]] || [[ "${TERM:-}" == "dumb" ]]; then
            mode=plain
        elif [[ -n "${NO_COLOR:-}" ]]; then
            mode=plain
        elif command -v tput &>/dev/null && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
            mode=color
        else
            mode=plain
        fi
    fi

    if [[ "$mode" == "unicode" ]] && { [[ ! -t 2 ]] || [[ "${TERM:-}" == "dumb" ]]; }; then
        mode=plain
    fi

    if [[ "$mode" != "plain" ]] && [[ -z "${NO_COLOR:-}" ]] \
        && command -v tput &>/dev/null && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
        NDS_UI_COLOR=true
    fi

    NDS_UI_MODE="$mode"
}

# Description: Format a bool for menus (yes/no).
nds_ui_format_bool() {
    local value="$1"
    local text

    nds_ui_init

    case "$value" in
        true) text=yes ;;
        false) text=no ;;
        *) echo "$value"; return 0 ;;
    esac

    if [[ "$NDS_UI_COLOR" == true ]]; then
        if [[ "$value" == true ]]; then
            printf '\033[32m%s\033[0m' "$text"
        else
            printf '\033[90m%s\033[0m' "$text"
        fi
        return 0
    fi

    echo "$text"
}

# Description: Print a label:value row at inner indent.
nds_ui_kv_row() {
    local label="$1"
    local value="$2"
    local width="${3:-$NDS_UI_LABEL_WIDTH}"

    nds_ui_init

    if [[ "$NDS_UI_COLOR" == true ]]; then
        printf "%s\033[1m%-${width}s\033[0m %s\n" "$NDS_UI_INDENT_I" "${label}:" "$value" >&2
    else
        printf "%s%-${width}s %s\n" "$NDS_UI_INDENT_I" "${label}:" "$value" >&2
    fi
}

# Description: Print a numbered menu choice row.
nds_ui_choice_row() {
    local number="$1"
    local name="$2"
    local detail="$3"
    local width="${4:-26}"

    nds_ui_kv_row "${number}) ${name}" "$detail" "$width"
}
