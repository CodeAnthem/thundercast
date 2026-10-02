#!/usr/bin/env bash
# ==================================================================================================
# NDS - Schema group cook
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Keys set by an action. Always enabled. Never asked.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_cook_phase_catalog() {
    printf '%s\n' \
        "leaf_push disk write_classic hardware_nix copy_configs stage_flake hardware_facter write_generated_host host_structure stage_host_files prefetch eval install_classic install_flake install_anywhere seed seed_git sops bootloader verify"
}

nds_check_phases() {
    local -n _phase_R=$1
    local _phase_list=${_phase_R[COOK_PHASES]:-} _phase_id _phase_cat _phase_last=-1 _phase_idx _phase_ok
    local -a _phase_ids=() _phase_cat_ids=()
    [[ -n "$_phase_list" ]] || return 0
    read -ra _phase_ids <<< "$_phase_list"
    read -ra _phase_cat_ids <<< "${ nds_cook_phase_catalog; }"
    for _phase_id in "${_phase_ids[@]}"; do
        _phase_ok=0
        _phase_idx=0
        for _phase_cat in "${_phase_cat_ids[@]}"; do
            if [[ "$_phase_cat" == "$_phase_id" ]]; then
                if (( _phase_idx <= _phase_last )); then
                    error "COOK_PHASES: ${_phase_id} is out of order"
                    return 1
                fi
                _phase_last=$_phase_idx
                _phase_ok=1
                break
            fi
            _phase_idx=$((_phase_idx + 1))
        done
        if (( _phase_ok == 0 )); then
            error "COOK_PHASES: unknown ${_phase_id}"
            return 1
        fi
    done
}

# Shared edges. The action still names the install phases between them.
nds_cook_plan_begin() {
    local -n _plan_R=$1
    local -a _plan_out=()
    [[ -n ${_plan_R[LEAF_PUSH_DIR]:-} ]] && _plan_out+=(leaf_push)
    [[ ${_plan_R[INSTALL_MODE]:-} != remote ]] && _plan_out+=(disk)
    printf '%s\n' "${_plan_out[*]}"
}

nds_cook_plan_local_tail() {
    local -n _plan_R=$1
    local -a _plan_out=()
    [[ ${_plan_R[INSTALL_MODE]:-} == remote ]] && return 0
    [[ -n ${_plan_R[TARGET_SEED_DIR]:-} ]] && _plan_out+=(seed)
    [[ ${_plan_R[GIT_PERSIST_ACCESS]:-} == true && -n ${_plan_R[GIT_KEYS_DIR]:-} ]] && _plan_out+=(seed_git)
    [[ -n ${_plan_R[SOPS_AGE_KEY_FILE]:-} ]] && _plan_out+=(sops)
    _plan_out+=(bootloader verify)
    printf '%s\n' "${_plan_out[*]}"
}

nds_schema_group cook "Cook" --check nds_check_phases
nds_schema_field cook LEAF_PUSH_DIR dir
nds_schema_field cook LEAF_PUSH_MESSAGE string
nds_schema_field cook TARGET_SEED_DIR dir
nds_schema_field cook COOK_PHASES string --label 'Cook phases'
