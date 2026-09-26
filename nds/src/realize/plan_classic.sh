#!/usr/bin/env bash
# ==================================================================================================
# NDS - Classic realize plan
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_realize_plan_classic() {
    local _plan_name=$1
    local -n _R=$1
    local _plan_cfg
    _plan_cfg="${ nds_session_dir config; }"
    eventRun realize.pre_disk "$_plan_name" || return 1
    _realize_step "Disk" step_disk "$_plan_name" || return 1
    eventRun realize.post_disk "$_plan_name" || return 1
    _realize_step "Configuration" nixcfg_writeClassic "$_plan_name" "${_plan_cfg}/configuration.nix" || return 1
    _realize_step "Hardware" step_hardware "$_plan_name" "$_plan_cfg" || return 1
    _realize_step "Copy configuration" nixos_copyConfigs "$_plan_cfg" /mnt || return 1
    eventRun realize.pre_install "$_plan_name" || return 1
    _realize_step "Install" nixos_installClassic /mnt || return 1
    if [[ -n ${_R[TARGET_SEED_DIR]:-} ]]; then
        _realize_step "Seed" step_seed "$_plan_name" || return 1
    fi
    eventRun realize.post_install "$_plan_name" || return 1
    _realize_step "EFI" step_efi "$_plan_name" || return 1
    _realize_step "Verify" nds_realize_verify classic || return 1
    nds_realize_diag "after install"
    eventRun realize.done "$_plan_name" || return 1
}
