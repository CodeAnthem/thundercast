#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast host CLI — shared UI (prompts / menus; NDS-free)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-08-31
# ==================================================================================================

# Description: Print a short section title.
tcast_ui_section() {
    printf '\n== %s ==\n' "$1"
}

# Description: Read a line from /dev/tty into REPLY (or fail non-interactively).
# Arguments:
# - prompt: <String>
# Returns:
# - <Bool> 0 when read
tcast_ui_ask() {
    local prompt="$1"
    REPLY=""
    [[ -e /dev/tty ]] || return 1
    read -rp "$prompt" REPLY < /dev/tty
}

# Description: Numbered menu; sets REPLY to the chosen label.
# Arguments:
# - title:   <String>
# - options: <String...> Labels (1-based); include a quit label yourself if wanted
# Returns:
# - <Bool> 0 when a valid choice was made
tcast_ui_menu() {
    local title="$1"
    shift
    local -a opts=("$@")
    local i choice
    [[ ${#opts[@]} -gt 0 ]] || return 1

    echo
    [[ -n "$title" ]] && echo "$title"
    for i in "${!opts[@]}"; do
        printf '  %d) %s\n' "$((i + 1))" "${opts[$i]}"
    done
    if ! tcast_ui_ask "choice: "; then
        return 1
    fi
    choice="$REPLY"
    [[ "$choice" =~ ^[0-9]+$ ]] || return 1
    (( choice >= 1 && choice <= ${#opts[@]} )) || return 1
    REPLY="${opts[$((choice - 1))]}"
}
