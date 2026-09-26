#!/usr/bin/env bash
# ==================================================================================================
# NDS - Remote flake cook plan
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_cook_plan_flake_remote() {
    local _plan_name=$1
    local -n _R=$1
    local _plan_stage _plan_host
    local -a _plan_extra=()
    _plan_stage="${ nds_session_dir work; }/flake-stage"
    _plan_host=${_R[FLAKE_HOST]:-}
    nixos_setBootContext "${_R[BOOT_LOADER]:-grub}" "${_R[BOOT_UEFI_MODE]:-}" \
        "${_R[DISK_TARGET]:-}" "${_R[ENCRYPTION]:-false}"
    eventRun cook.pre_disk "$_plan_name" || return 1
    if [[ -n ${_R[LEAF_PUSH_DIR]:-} ]]; then
        _cook_step "Leaf push" step_leafPush "$_plan_name" || return 1
    fi
    _cook_step "Stage flake" step_stageFlake "$_plan_name" "$_plan_stage" || return 1
    _cook_step "Prefetch" nixos_prefetchFlake "$_plan_stage" "${_R[GIT_KEYS_DIR]:-}" || return 1
    _cook_step "Eval" nixos_flakeEval "$_plan_stage" "$_plan_host" || return 1
    eventRun cook.pre_install "$_plan_name" || return 1
    mapfile -t _plan_extra < <(step_seedRemoteArgs "$_plan_name")
    if [[ -n ${_R[ENCRYPTION_KEY_FILE]:-} ]]; then
        _plan_extra+=(--key-file "${_R[ENCRYPTION_KEY_FILE]}")
    fi
    _cook_step "Install" nixos_anywhere "$_plan_stage" "$_plan_host" \
        "${_R[REMOTE_TARGET_IP]}" "${_plan_stage}/facter.json" "${_R[ENCRYPTION_KEY_FILE]:-}" \
        ${_plan_extra[@]+"${_plan_extra[@]}"} || return 1
    eventRun cook.post_install "$_plan_name" || return 1
    eventRun cook.done "$_plan_name" || return 1
}
