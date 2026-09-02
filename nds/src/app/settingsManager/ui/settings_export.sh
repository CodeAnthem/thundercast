#!/usr/bin/env bash
# ==================================================================================================
# NDS - Settings Manager UI: export / confirm / preset summary
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-08-27
# ==================================================================================================

declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_CONFIG_CONFIRM_SKIP

# Description: Print changed-from-defaults export lines for the operator.
# Unattended: write to the install log only (bundle already stores the full export).
nds_cfg_print_backup() {
    local line count=0
    nds_mode_resolve || true
    if declare -f nds_mode_is_unattended &>/dev/null && nds_mode_is_unattended; then
        while IFS= read -r line; do
            [[ -n "$line" ]] || continue
            declare -f nds_install_log &>/dev/null && nds_install_log "$line"
        done < <(nds_cfg_export_modified)
        return 0
    fi

    nds_ui_section_header "Configuration export"
    nds_ui_b "Only values changed from defaults (export NDS_*= lines)."
    nds_ui_b "The backup bundle has nds-restore.recipe — set NDS_RECIPE_FILE to it on a live ISO."
    nds_ui_b ""
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        nds_ui_i "$line"
        count=$((count + 1))
    done < <(nds_cfg_export_modified)
    if [[ -n "${NDS_CURRENT_ACTION:-}" ]]; then
        nds_ui_i "export NDS_ACTION=\"${NDS_CURRENT_ACTION}\""
        count=$((count + 1))
    fi
    if [[ "$count" -eq 0 ]]; then
        nds_ui_i "# (no changes from defaults)"
    fi
    nds_ui_b ""
}

# Description: Confirm leaving settings menu into install review.
nds_cfg_confirm_saved() {
    if nds_skip_menu NDS_CONFIG_CONFIRM_SKIP; then
        nds_log_from_env "Configuration review confirmation skipped"
        return 0
    fi
    nds_ask_user_to_proceed "Continue to installation review" || return 1
    return 0
}

# Description: Print a preset display header and optional summary hook.
# Arguments:
# - preset: <String> Preset id
# - number: <String|optional> Menu index prefix
nds_cfg_preset_summary() {
    local preset="$1" number="${2:-}"
    local display fn
    display=${ nds_cfg_preset_get_display "$preset"; }
    if [[ -n "$number" ]]; then
        nds_ui_h "$number. $display"
    else
        nds_ui_h "${display}:"
    fi
    if fn="${ _nds_preset_hook_fn "$preset" summary; }"; then
        "$fn"
    fi
}
