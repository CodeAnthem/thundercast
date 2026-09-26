#!/usr/bin/env bash
# ==================================================================================================
# NDS - Remote flake realize plan
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_realize_plan_flake_remote() {
    local _plan_name=$1
    local -n _R=$1
    local _plan_stage _plan_host
    local -a _plan_extra=()
    _plan_stage="${ nds_session_dir work; }/flake-stage"
    _plan_host=${_R[FLAKE_HOST]:-}
    eventRun realize.pre_disk "$_plan_name" || return 1
    if [[ -n ${_R[LEAF_PUSH_DIR]:-} ]]; then
        _realize_step "Leaf push" step_leafPush "$_plan_name" || return 1
    fi
    _realize_step "Stage flake" step_stageFlake "$_plan_name" "$_plan_stage" || return 1
    _realize_step "Prefetch" nixos_prefetchFlake "$_plan_stage" || return 1
    _realize_step "Eval" nixos_flakeEval "$_plan_stage" "$_plan_host" || return 1
    eventRun realize.pre_install "$_plan_name" || return 1
    mapfile -t _plan_extra < <(step_seedRemoteArgs "$_plan_name")
    if [[ -n ${_R[ENCRYPTION_KEY_FILE]:-} ]]; then
        _plan_extra+=(--key-file "${_R[ENCRYPTION_KEY_FILE]}")
    fi
    _realize_step "Install" nixos_anywhere "${_R[REMOTE_TARGET_IP]}" "$_plan_stage" "$_plan_host" \
        ${_plan_extra[@]+"${_plan_extra[@]}"} || return 1
    eventRun realize.post_install "$_plan_name" || return 1
    eventRun realize.done "$_plan_name" || return 1
}
