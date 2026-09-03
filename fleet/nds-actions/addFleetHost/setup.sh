#!/usr/bin/env bash
# ==================================================================================================
# NDS - addFleetHost composer (generate flake host from a role, then Part A)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-20 | Modified: 2026-08-28
# Description:   Scaffold a nixosConfiguration from .roles/, write recipe, optional install
# ==================================================================================================

action_presets() {
    printf '%s\n' addFleetHost installFlake network boot disk encryption
}

action_config() {
    nds_cfg_preset_set_display addFleetHost "Role"
    nds_cfg_preset_set_priority addFleetHost 19
    nds_cfg_preset_set_priority installFlake 20
    nds_cfg_preset_set_priority network 21
    nds_cfg_preset_set_priority boot 22
    nds_cfg_preset_set_priority disk 23
    nds_cfg_preset_set_priority encryption 24
    nds_cfg_set INSTALL_KIND "flake"
    nds_cfg_set INSTALL_COMPOSER "addFleetHost"
}

action_preview() {
    nds_ui_h "New flake host from a leaf role"
    nds_ui_b ""
    nds_ui_b "This is generate, then install:"
    nds_ui_i "clone the install flake (write git access)"
    nds_ui_i "pick a .roles/ template and scaffold hosts/<system>/<host>/"
    nds_ui_i "write a portable recipe to .nds/hosts/<host>.recipe (no secrets)"
    nds_ui_i "confirm disk wipe, then push, then Part A partitions and flake-installs"
    nds_ui_b ""
}

# Description: Scaffold + recipe + push. Does not install (Part A does).
nds_addFleetHost_compose() {
    local flake_root system role host mode
    flake_root="${NDS_FLAKE_PROBE_DIR:-.}"
    system="$(basename "${NDS_FLAKE_HOST_DIR:-hosts/x86_64-linux}")"
    host="$(nds_cfg_get FLAKE_HOST)"
    role="$(nds_cfg_get SCAFFOLD_ROLE)"
    mode="$(nds_cfg_get SCAFFOLD_MODE)"
    mode="${mode:-new}"

    [[ -n "$host" ]] || {
        error "Host name is empty — pick a host after choosing a role"
        return 1
    }

    if [[ "$mode" == "new" ]]; then
        nds_flake_scaffold_apply "$flake_root" "$system" || return 1
    fi

    nds_flake_write_host_nds_env "$flake_root" "$host" || return 1
    nds_install_flake_run_hooks "$flake_root" post_scaffold || return 1

    nds_install_flake_commit_push_leaf "$flake_root" \
        "nds: ${mode} host ${host}${role:+ (role ${role})}" || return 1

    nds_install_flake_run_hooks "$flake_root" pre_install || return 1
    return 0
}

action_setup() {
    nds_mode_resolve || true

    if [[ -z "$(nds_cfg_get FLAKE_REPO_URL)" ]]; then
        if nds_mode_is_unattended; then
            error "FLAKE_REPO_URL is required"
            exit 11
        fi
        nds_cfg_ask_url FLAKE_REPO_URL "Install flake Git URL" "" true
    fi

    nds_install_open_leaf || exit 14

    local flake_root system
    flake_root="${NDS_FLAKE_PROBE_DIR:-.}"
    system="$(basename "${NDS_FLAKE_HOST_DIR:-hosts/x86_64-linux}")"
    if ! nds_flake_role_select "$flake_root" "$system"; then
        error "Leaf has no .roles/ (or profiles/) — copy thundercast/fleet/exampleRepo"
        exit 14
    fi
    nds_flake_prepare

    if ! nds_sm_validate; then
        if nds_mode_is_unattended; then
            error "Unattended mode: configuration incomplete"
            exit 11
        fi
        nds_cfg_prompt_errors
        nds_sm_validate || exit 11
    fi
    nds_sm_menu || exit 12
    nds_realize_confirm || exit 13

    nds_addFleetHost_compose || exit 15
    nds_cfg_set INSTALL_KIND "flake"
    nds_realize_run || exit $?
    nds_install_flake_run_hooks "${NDS_FLAKE_PROBE_DIR:-.}" post_install || exit 15
}
