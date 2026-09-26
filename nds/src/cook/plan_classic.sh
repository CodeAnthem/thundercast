#!/usr/bin/env bash
# ==================================================================================================
# NDS - Classic cook plan
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_cook_plan_classic() {
    local _plan_name=$1
    local -n _R=$1
    local _plan_cfg
    nixos_setBootContext "${_R[BOOT_LOADER]:-grub}" "${_R[BOOT_UEFI_MODE]:-}" \
        "${_R[DISK_TARGET]:-}" "${_R[ENCRYPTION]:-false}"
    _plan_cfg="${ nds_session_dir config; }"
    eventRun cook.pre_disk "$_plan_name" || return 1
    _cook_step "Disk" step_disk "$_plan_name" || return 1
    eventRun cook.post_disk "$_plan_name" || return 1
    _cook_step "Configuration" nixcfg_writeClassic "$_plan_name" "${_plan_cfg}/configuration.nix" || return 1
    _cook_step "Hardware" step_hardware "$_plan_name" "$_plan_cfg" || return 1
    _cook_step "Copy configuration" nixos_copyConfigs "$_plan_cfg" "$_NDS_TARGET_ROOT" || return 1
    eventRun cook.pre_install "$_plan_name" || return 1
    _cook_step "Install" nixos_installClassic "$_NDS_TARGET_ROOT" || return 1
    if [[ -n ${_R[TARGET_SEED_DIR]:-} ]]; then
        _cook_step "Seed" step_seed "$_plan_name" || return 1
    fi
    eventRun cook.post_install "$_plan_name" || return 1
    _cook_step "EFI" step_efi "$_plan_name" || return 1
    _cook_step "Verify" nds_cook_verify "$_plan_name" classic || return 1
    nds_cook_diag "after install"
    eventRun cook.done "$_plan_name" || return 1
}
