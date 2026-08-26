#!/usr/bin/env bash
# ==================================================================================================
# NDS - Catalog gate UI (remoteAction)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-18 | Modified: 2026-08-26
# Description:   Ask catalog Git URL; list and pick .nds/actions
# ==================================================================================================

# Description: Prompt for CAST_REPO_URL (default Thundercast). Unattended keeps
# env/default. Back from the prompt is treated as action-menu back.
# Returns:
# - 0 when a URL is set
nds_cast_ui_ask_catalog() {
    local current default
    default="${NDS_CAST_DEFAULT_URL:-https://github.com/CodeAnthem/thundercast.git}"
    current="$(nds_cfg_get CAST_REPO_URL 2>/dev/null || true)"
    [[ -n "$current" ]] || current="${NDS_CAST_REPO_URL:-}"

    if nds_mode_is_unattended; then
        [[ -n "$current" ]] || current="$default"
        nds_cfg_set CAST_REPO_URL "$current"
        nds_log_from_env "Remote actions: ${current}"
        return 0
    fi

    [[ -n "$current" ]] || current="$default"
    nds_cfg_set CAST_REPO_URL "$current"
    nds_ui_section_header "Remote actions"
    nds_ui_b ""
    nds_ui_b "Git repo that contains YOUR .nds/actions (not ThunderCast builtins)."
    nds_ui_b "addRole and toolkit are built-in NDS actions — pick them from the main menu."
    nds_ui_b "Default URL is ThunderCast (public HTTPS). That repo has no user catalog actions."
    nds_ui_b "A public HTTPS remote-action repo clones with no key."
    nds_ui_b ""
    nds_cfg_ask_url CAST_REPO_URL "Remote-action Git URL" "$current" true
    [[ -n "$(nds_cfg_get CAST_REPO_URL)" ]] || return 1
    return 0
}

# Description: One warning before NDS first fetches a remote-action repo.
# Skip with NDS_CAST_WARN_SKIP=true (also NDS_AUTO_CONFIRM / unattended).
# Arguments:
# - catalog: <String> Remote-action git URL
# Returns:
# - 0 proceed; NDS_ACTION_BACK on no/back
nds_cast_ui_confirm_fetch() {
    local catalog="$1" rc

    declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_CAST_WARN_SKIP

    if nds_mode_is_unattended || nds_skip_menu NDS_CAST_WARN_SKIP; then
        nds_log_from_env "Remote-action fetch confirm skipped"
        return 0
    fi

    nds_ui_section_header "Remote actions"
    nds_ui_b ""
    nds_ui_warn "NDS will clone this git repository and later run scripts from it"
    nds_ui_warn "with installer privileges. Do not use a repository you do not trust."
    nds_ui_b ""
    [[ -n "$catalog" ]] && nds_ui_i "Repository: ${catalog}"
    nds_ui_b ""
    nds_ui_b "Press Y to continue, B to go back."
    nds_ui_b ""
    nds_ask_user_continue "Proceed with this repository?"
    rc=$?
    case "$rc" in
        0) return 0 ;;
        *) return "${NDS_ACTION_BACK:-10}" ;;
    esac
}

# Description: Numbered menu of catalog actions. 0 goes back to the action list.
# Arguments:
# - cast_root: <String> Catalog checkout
# Returns:
# - 0 with CAST_ACTION set; 1 on back; 14 when the catalog has no user actions
nds_cast_ui_pick_action() {
    local cast_root="$1"
    local actions labels id desc i choice max_choice prompt
    local -a ids=() label_arr=()

    actions="$(nds_cast_require_user_actions "$cast_root")" || return 14

    labels="$(nds_cast_action_labels "$cast_root" "$actions")"
    IFS='|' read -ra ids <<< "$actions"
    IFS='|' read -ra label_arr <<< "$labels"

    while true; do
        nds_ui_section_header "Choose a remote action"
        nds_ui_b ""
        nds_ui_choice_row "0" "Back" "Return to the action menu"
        nds_ui_b ""
        i=1
        for id in "${ids[@]}"; do
            desc="${label_arr[$((i - 1))]}"
            desc="${desc#*=}"
            [[ -n "$desc" ]] || desc="$id"
            nds_ui_choice_row "$i" "$id" "$desc"
            ((i++))
        done
        nds_ui_b ""
        max_choice="${#ids[@]}"
        prompt="$(nds_ui_numbered_prompt 0 "$max_choice" "" "Make your selection" true)"
        choice=""
        if nds_ui_read_menu_digit choice "$prompt" 0 "$max_choice" true; then
            if [[ "$choice" == "0" ]]; then
                return 1
            fi
            nds_cfg_set CAST_ACTION "${ids[$((choice - 1))]}"
            return 0
        fi
        nds_ui_b "Invalid selection. Choose 0-${max_choice}"
    done
}
