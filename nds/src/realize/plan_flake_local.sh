#!/usr/bin/env bash
# ==================================================================================================
# NDS - Local flake realize plan
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_realize_plan_flake_local() {
    local _plan_name=$1
    local -n _R=$1
    local _plan_install _plan_host _plan_rel _plan_host_dir _plan_secrets
    _plan_install=${_R[FLAKE_INSTALL_PATH]:-/mnt/etc/nixos}
    _plan_host=${_R[FLAKE_HOST]:-}
    _plan_rel=${_R[FLAKE_HOST_DIR]:-hosts/x86_64-linux}
    _plan_host_dir="${_plan_install}/${_plan_rel}/${_plan_host}"
    _plan_secrets="${ nds_session_dir secrets; }"
    eventRun realize.pre_disk "$_plan_name" || return 1
    if [[ -n ${_R[LEAF_PUSH_DIR]:-} ]]; then
        _realize_step "Leaf push" step_leafPush "$_plan_name" || return 1
    fi
    _realize_step "Disk" step_disk "$_plan_name" || return 1
    eventRun realize.post_disk "$_plan_name" || return 1
    _realize_step "Stage flake" step_stageFlake "$_plan_name" "$_plan_install" || return 1
    _realize_step "Hardware" step_hardware "$_plan_name" "$_plan_host_dir" || return 1
    _realize_step "Generated host" nixcfg_writeGeneratedHost "$_plan_name" "$_plan_host_dir" \
        "$_plan_host" "${_R[DISK_TARGET]:-}" "${_R[ENCRYPTION]:-false}" "$_plan_install" || return 1
    eventRun realize.pre_install "$_plan_name" || return 1
    _realize_step "Prefetch" nixos_prefetchFlake "$_plan_install" || return 1
    _realize_step "Eval" nixos_flakeEval "$_plan_install" "$_plan_host" || return 1
    _realize_step "Install" nixos_installFlake "$_plan_install" "$_plan_host" || return 1
    if [[ -n ${_R[TARGET_SEED_DIR]:-} ]]; then
        _realize_step "Seed" step_seed "$_plan_name" || return 1
    fi
    if [[ ${_R[GIT_PERSIST_ACCESS]:-} == true && -n ${_R[GIT_KEYS_DIR]:-} ]]; then
        _realize_step "Git keys" step_seedGit "$_plan_name" || return 1
    fi
    if [[ -n ${_R[SOPS_AGE_KEY_FILE]:-} ]]; then
        _realize_step "Sops" sops_installKey "${_R[SOPS_AGE_KEY_FILE]}" /mnt "$_plan_secrets" "$_plan_host" || return 1
    fi
    eventRun realize.post_install "$_plan_name" || return 1
    _realize_step "EFI" step_efi "$_plan_name" || return 1
    _realize_step "Verify" nds_realize_verify flake "$_plan_install" || return 1
    nds_realize_diag "after install"
    eventRun realize.done "$_plan_name" || return 1
}
