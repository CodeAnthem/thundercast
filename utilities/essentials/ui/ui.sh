#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - UI
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-17 | Modified: 2026-09-20
# ==================================================================================================
#
# Format toolkit: indent, color, rows, banner/section. Owns screen events
# ui.line.take and ui.section.begin. Step and prompt are siblings.
#
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_essentials_ui_init() {
    [[ "${__UI_INITIALIZED:-false}" == true ]] && return 0

    local -n config="essentials_config"
    local banner_min="${config[UI_BANNER_MIN]:-56}"
    local label_width="${config[UI_LABEL_WIDTH]:-38}"

    [[ "$banner_min" =~ ^[0-9]+$ ]] || banner_min=56
    [[ "$label_width" =~ ^[0-9]+$ ]] || label_width=38

    declare -g __UI_MODE="${config[UI_MODE]:-auto}"
    declare -g __UI_NO_CLEAR="${config[UI_NO_CLEAR]:-false}"
    declare -g __UI_BANNER_MIN="$banner_min"
    declare -g __UI_LABEL_WIDTH="$label_width"
    declare -g __UI_COLOR=false
    declare -g __UI_WARN_CODE=33
    declare -g __UI_INDENT_H=' '
    declare -g __UI_INDENT_B='  '
    declare -g __UI_INDENT_I='    '
    declare -ga __UI_INDENT_STACK=()
    declare -g __UI_BANNER_SUBTITLE=""

    # shellcheck source=./ui_base.sh
    loadModule "ui/ui_base.sh"
    _ui_baseDetect
    unset -f _ui_baseDetect

    # shellcheck source=./ui_section.sh
    loadModule "ui/ui_section.sh"

    if declare -f eventCreate &>/dev/null; then
        eventCreate ui.line.take || return 1
        eventCreate ui.section.begin || return 1
    fi

    declare -g __UI_INITIALIZED=true
}

_essentials_ui_init || return 1
