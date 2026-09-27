#!/usr/bin/env bash
# ==================================================================================================
# NDS - Local flake cook plan
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_cook_plan_flake_local() {
    local _plan_name=$1
    local -n _R=$1
    local _plan_install _plan_host _plan_rel _plan_host_dir _plan_secrets
    _plan_install=${_R[FLAKE_INSTALL_PATH]:-${_NDS_TARGET_ROOT}/etc/nixos}
    _plan_host=${_R[FLAKE_HOST]:-}
    _plan_rel=${_R[FLAKE_HOST_DIR]:-hosts/x86_64-linux}
    _plan_host_dir="${_plan_install}/${_plan_rel}/${_plan_host}"
    _plan_secrets="${ nds_session_dir secrets; }"
    nixos_setBootContext "${_R[BOOT_LOADER]:-grub}" "${_R[BOOT_UEFI_MODE]:-}" \
        "${_R[DISK_TARGET]:-}" "${_R[ENCRYPTION]:-false}"
    eventRun cook.pre_disk "$_plan_name" || return 1
    if [[ -n ${_R[LEAF_PUSH_DIR]:-} ]]; then
        _cook_step "Leaf push" step_leafPush "$_plan_name" || return 1
    fi
    _cook_step "Disk" step_disk "$_plan_name" || return 1
    eventRun cook.post_disk "$_plan_name" || return 1
    _cook_step "Stage flake" step_stageFlake "$_plan_name" "$_plan_install" || return 1
    _cook_step "Generate facter.json" step_hardware "$_plan_name" "$_plan_host_dir" || return 1
    _cook_step "Generated host" nixcfg_writeGeneratedHost "$_plan_name" "$_plan_host_dir" || return 1
    _cook_step "Host structure" flake_hostStructureOk "$_plan_host_dir" || return 1
    _cook_step "Stage host files" flake_gitStageHostFiles "$_plan_install" "$_plan_host_dir" \
        nds_generated.nix configuration.nix || return 1
    eventRun cook.pre_install "$_plan_name" || return 1
    _cook_step "Prefetch" nixos_prefetchFlake "$_plan_install" "${_R[GIT_KEYS_DIR]:-}" || return 1
    _cook_step "Eval" nixos_flakeEval "$_plan_install" "$_plan_host" || return 1
    _cook_step "Install" nixos_installFlake "$_plan_install" "$_plan_host" "$_plan_host_dir" \
        "${_R[FLAKE_HARDWARE_PLACEMENT]:-host-dir}" || return 1
    if [[ -n ${_R[TARGET_SEED_DIR]:-} ]]; then
        _cook_step "Seed" step_seed "$_plan_name" || return 1
    fi
    if [[ ${_R[GIT_PERSIST_ACCESS]:-} == true && -n ${_R[GIT_KEYS_DIR]:-} ]]; then
        _cook_step "Git keys" step_seedGit "$_plan_name" || return 1
    fi
    if [[ -n ${_R[SOPS_AGE_KEY_FILE]:-} ]]; then
        _cook_step "Sops" sops_installKey "${_R[SOPS_AGE_KEY_FILE]}" "$_NDS_TARGET_ROOT" "$_plan_secrets" "$_plan_host" || return 1
    fi
    eventRun cook.post_install "$_plan_name" || return 1
    _cook_step "EFI" step_efi "$_plan_name" || return 1
    _cook_step "Verify" nds_cook_verify "$_plan_name" flake || return 1
    eventRun cook.done "$_plan_name" || return 1
}
