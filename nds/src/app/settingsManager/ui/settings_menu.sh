#!/usr/bin/env bash
# ==================================================================================================
# NDS - Configuration menu
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-08-27
# Description:   Category menu — calls per-preset configure/summary/validate (no hook framework)
# ==================================================================================================

declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_SKIP_MENU

# Description: Re-prompt invalid fields for the given presets (or all enabled).
nds_cfg_prompt_errors() {
    local presets=("$@") preset fixed=false
    if [[ ${#presets[@]} -eq 0 ]]; then
        readarray -t presets < <(nds_cfg_preset_get_all_enabled)
    fi
    for preset in "${presets[@]}"; do
        if ! nds_cfg_preset_validate "$preset" 2>/dev/null; then
            fixed=true
            break
        fi
    done
    [[ "$fixed" == true ]] || return 0

    # Presets may draw their own Configuration section (e.g. installFlake).
    if ! _nds_preset_has_hook installFlake prompt_errors \
        || [[ " ${presets[*]} " != *" installFlake "* ]]; then
        nds_ui_section_header "Configuration — required fields"
    fi
    for preset in "${presets[@]}"; do
        if ! nds_cfg_preset_validate "$preset" 2>/dev/null; then
            nds_cfg_preset_prompt_errors "$preset"
        fi
    done
}

# Description: Interactive settings category menu.
nds_cfg_menu() {
    local last_status="" sel="" prompt=""
    local -a menu_presets=() validate_presets=()
    if [[ $# -eq 0 ]]; then
        readarray -t validate_presets < <(nds_cfg_preset_get_all_enabled)
        readarray -t menu_presets < <(nds_cfg_preset_get_all_menu)
    else
        menu_presets=("$@")
        validate_presets=("$@")
    fi

    while true; do
        nds_ui_section_header "Configuration"
        [[ -n "$last_status" ]] && nds_ui_b "$last_status" && nds_ui_b ""
        nds_ui_b "Pick a category to fine-tune, or press X when ready to install."
        nds_ui_b ""

        local i=0 preset
        for preset in "${menu_presets[@]}"; do
            ((++i))
            nds_cfg_preset_summary "$preset" "$i"
            nds_ui_b ""
        done

        prompt="${ nds_ui_numbered_prompt 1 "$i" "" "Select category" false true; }"
        while true; do
            sel=""
            if ! nds_ui_read_menu_digit sel "$prompt" 1 "$i" false true; then
                continue
            fi

            if [[ "$sel" == "x" ]]; then
                if ! nds_cfg_validate_all "${validate_presets[@]}"; then
                    nds_cfg_prompt_errors "${validate_presets[@]}"
                    if ! nds_cfg_validate_all "${validate_presets[@]}"; then
                        last_status="Configuration has errors — complete the required fields above."
                        warn "$last_status"
                        break
                    fi
                    last_status="Required fields updated"
                    success "$last_status"
                    break
                fi
                success "Configuration confirmed"
                nds_cfg_print_backup
                nds_cfg_confirm_saved || {
                    last_status="Press Y to continue to installation review, or X to try again."
                    warn "$last_status"
                    break
                }
                return 0
            fi

            if [[ "$sel" =~ ^[0-9]+$ ]] && [[ "$sel" -ge 1 ]] && [[ "$sel" -le "$i" ]]; then
                preset="${menu_presets[$((sel-1))]}"
                nds_ui_section_header "${ nds_cfg_preset_get_display "$preset"; } Configuration"
                nds_ui_b "Press ENTER to keep current value, or type a new value"
                nds_ui_b ""
                nds_cfg_preset_configure "$preset"
                if nds_cfg_preset_validate "$preset" 2>/dev/null; then
                    last_status="${ nds_cfg_preset_get_display "$preset"; } updated"
                    success "$last_status"
                else
                    last_status="${ nds_cfg_preset_get_display "$preset"; } has errors — fix before pressing X."
                    warn "$last_status"
                fi
                break
            fi
            warn "Invalid selection"
        done
    done
}

# Description: Skip category menu when NDS_SKIP_MENU / unattended and validation passes.
nds_cfg_menu_or_skip() {
    local presets=("$@")

    nds_mode_resolve || true

    if declare -f nds_mode_is_unattended &>/dev/null && nds_mode_is_unattended; then
        if ! nds_cfg_validate_all "${presets[@]}"; then
            error "Unattended mode: configuration incomplete or invalid"
            return 1
        fi
        nds_log_from_env "Configuration complete"
        nds_cfg_print_backup
        return 0
    fi

    if nds_skip_menu NDS_SKIP_MENU; then
        if ! nds_cfg_validate_all "${presets[@]}"; then
            nds_cfg_prompt_errors "${presets[@]}"
            nds_cfg_validate_all "${presets[@]}" || return 1
        fi
        nds_log_from_env "Configuration complete (menu skipped)"
        nds_cfg_print_backup
        if nds_skip_menu NDS_CONFIG_CONFIRM_SKIP; then
            return 0
        fi
        nds_cfg_confirm_saved || return 1
        return 0
    fi
    nds_cfg_menu "${presets[@]}"
}
