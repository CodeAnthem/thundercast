#!/usr/bin/env bash
# ==================================================================================================
# NDS realize - turn a validated settings session into an installed system
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-20 | Modified: 2026-09-03
# Description:   Entry (nds_realize_run) + one confirm gate. Plans live in plan_*.sh; every step
#                reads settings once (nds_cfg_get) and hands plain arguments to utilities.
#                Composers (actions) validate, then call nds_realize_run. Nothing else installs.
# ==================================================================================================

# Description: Resolve INSTALL_KIND (classic | flake); infer flake when flake keys are set.
# Returns:
# - <String> classic | flake (stdout)
nds_realize_kind() {
    local kind
    kind="$(nds_cfg_get INSTALL_KIND)"
    if [[ -n "$kind" ]]; then
        printf '%s\n' "$kind"
        return 0
    fi
    if [[ -n "$(nds_cfg_get FLAKE_HOST)" \
        || -n "$(nds_cfg_get FLAKE_REPO_URL)" \
        || -n "$(nds_cfg_get FLAKE_LOCAL_PATH)" ]]; then
        printf 'flake\n'
        return 0
    fi
    printf 'classic\n'
}

# Description: Effective install mode (local | remote).
# Returns:
# - <String> mode (stdout)
nds_realize_mode() {
    local mode
    mode="$(nds_cfg_get INSTALL_MODE)"
    printf '%s\n' "${mode:-local}"
}

# Description: Preflight + wipe confirmation — exactly once per session (NDS_INSTALL_CONFIRMED).
# Composers that git-push before install call this after their settings menu; nds_realize_run
# calls it too, so no second confirm screen appears.
# Returns:
# - <Bool> 0 when confirmed; 1 when the user declined or preflight failed
nds_realize_confirm() {
    local kind mode disk strategy uefi loader target_ip

    [[ "${NDS_INSTALL_CONFIRMED:-}" == "1" ]] && return 0
    kind="${ nds_realize_kind; }"
    mode="${ nds_realize_mode; }"
    disk="$(nds_cfg_get DISK_TARGET)"
    strategy="$(nds_cfg_get DISK_STRATEGY)"
    strategy="${strategy:-nds}"
    uefi="$(nds_cfg_get BOOT_UEFI_MODE)"
    loader="$(nds_cfg_get BOOT_LOADER)"

    if [[ "$kind" == "flake" && "$mode" == "remote" ]]; then
        target_ip="$(nds_cfg_get REMOTE_TARGET_IP)"
        nds_realize_preflight_remote "$target_ip" || return 1
        nds_install_ui_confirm_remote "$target_ip" || return 1
    else
        nds_realize_preflight_local "$disk" "$uefi" "$loader" || return 1
        nds_install_ui_confirm_install "$disk" "$strategy" || return 1
    fi
    export NDS_INSTALL_CONFIRMED=1
    return 0
}

# Description: Realize the live settings session (Part A).
# Returns:
# - <Int> 0 on success; 11 invalid config, 13 declined, 14 compose files, 15 install, 16 finish
nds_realize_run() {
    local kind mode

    nds_mode_resolve || true
    if declare -f nds_sm_materialize_secrets &>/dev/null; then
        nds_sm_materialize_secrets || return 11
    fi
    if ! nds_sm_validate; then
        error "Realize: configuration incomplete or invalid"
        return 11
    fi

    kind="${ nds_realize_kind; }"
    mode="${ nds_realize_mode; }"
    nds_cfg_set INSTALL_KIND "$kind"

    nds_realize_confirm || return 13
    nds_install_ui_section_nixos_install
    nds_install_log "realize: ${kind} (mode=${mode}) starting"

    case "$kind" in
        classic)
            _nds_realize_plan_classic || return $?
            nds_install_finish || return 16
            ;;
        flake)
            if [[ "$mode" == "remote" ]]; then
                _nds_realize_plan_flake_remote || return $?
            else
                _nds_realize_plan_flake_local || return $?
            fi
            export NDS_GIT_INSTALL_SUCCEEDED=true
            nds_git_access_cleanup_success
            if [[ "$mode" == "remote" ]]; then
                nds_install_remote_finish || return 16
            else
                nds_install_finish || return 16
            fi
            ;;
        *)
            error "Unknown INSTALL_KIND=${kind} (classic|flake)"
            return 11
            ;;
    esac
    nds_install_log "realize: ${kind} completed"
    return 0
}
