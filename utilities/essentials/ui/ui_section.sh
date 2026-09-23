#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - UI - Section
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-17 | Modified: 2026-09-21
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

# Print the banner box (scriptInfo name/version + optional subtitle).
ui_banner() {
    local subtitle="${1:-}"
    local name="Script" version="" title_line sub_line inner border margin='  '
    if declare -f scriptInfo_get_name &>/dev/null; then
        name=${ scriptInfo_get_name; }
        version=${ scriptInfo_get_version; }
    fi
    title_line=" === ${name} v${version} === "
    sub_line="  ${subtitle}"
    inner=${#title_line}
    (( ${#sub_line} > inner )) && inner=${#sub_line}
    (( inner < __UI_BANNER_MIN )) && inner=${__UI_BANNER_MIN}
    printf -v border '%*s' "$inner" ''
    border="${border// /-}"

    printf "%s+%s+\n" "$margin" "$border" >&2
    printf "%s|%s%*s|\n" "$margin" "$title_line" "$(( inner - ${#title_line} ))" '' >&2
    [[ -n "$subtitle" ]] && printf "%s|%s%*s|\n" "$margin" "$sub_line" "$(( inner - ${#sub_line} ))" '' >&2
    printf "%s+%s+\n" "$margin" "$border" >&2
}

# Optional clear, redraw banner with this subtitle.
# Fires ui.section.begin first (task fails an open progress line).
ui_section() {
    local subtitle="${1:-}"
    __UI_BANNER_SUBTITLE="$subtitle"
    if declare -f eventRun &>/dev/null && eventHas ui.section.begin; then
        eventRun ui.section.begin || return 1
    fi
    if [[ "${__UI_NO_CLEAR}" != true ]]; then
        if declare -f chrome_isOn &>/dev/null && chrome_isOn; then
            # Body only — jump so the banner sits at the top of the chrome pane.
            chrome_clear
        elif [[ -t 2 ]]; then
            printf '\033[2J\033[H' >&2
        fi
    fi
    ui_banner "$__UI_BANNER_SUBTITLE"
}
