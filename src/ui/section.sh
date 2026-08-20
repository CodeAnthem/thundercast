#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI sections (banner + screen titles)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-08-06
# Description:   Persistent NDS banner and section screen transitions
# ==================================================================================================

declare -g NDS_UI_BANNER_SUBTITLE=""

# Description: Render the persistent NDS banner as a single box (title + optional subtitle).
# Arguments:
# - subtitle: <String> Current section/screen name (may be empty)
nds_ui_banner() {
    local subtitle="${1:-}"
    local title_line=" === ${SCRIPT_NAME:-Nix Deploy System} v${SCRIPT_VERSION:-} === "
    local sub_line="  ${subtitle}"
    local inner=${#title_line}
    (( ${#sub_line} > inner )) && inner=${#sub_line}
    (( inner < 56 )) && inner=56

    nds_ui_init

    local margin='  '
    local border
    border=$(printf -- '-%.0s' $(seq 1 "$inner"))

    printf "%s+%s+\n" "$margin" "$border" >&2
    printf "%s|%s%*s|\n" "$margin" "$title_line" "$(( inner - ${#title_line} ))" '' >&2
    [[ -n "$subtitle" ]] && printf "%s|%s%*s|\n" "$margin" "$sub_line" "$(( inner - ${#sub_line} ))" '' >&2
    printf "%s+%s+\n" "$margin" "$border" >&2
}

# Description: Clear the screen and redraw the persistent NDS banner.
nds_ui_new_section() {
    printf '\033[2J\033[H' >&2
    nds_ui_banner "${NDS_UI_BANNER_SUBTITLE:-}"
}

# Description: Show a screen with the banner and a raw subtitle.
nds_ui_section_title() {
    NDS_UI_BANNER_SUBTITLE="$1"
    nds_ui_new_section
}

# Description: Show a screen with the banner and a subsection subtitle,
# prefixed with the current action name when inside one.
nds_ui_section_header() {
    local label="$1"
    if [[ -n "${NDS_CURRENT_ACTION:-}" ]]; then
        NDS_UI_BANNER_SUBTITLE="${NDS_CURRENT_ACTION} — ${label}"
    else
        NDS_UI_BANNER_SUBTITLE="$label"
    fi
    nds_ui_new_section
}
