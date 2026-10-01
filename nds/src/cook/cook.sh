#!/usr/bin/env bash
# ==================================================================================================
# NDS - Birth a machine from a sealed recipe
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-29
# Description:   Load, validate, preflight, then run COOK_PHASES. No TTY.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

declare -g _NDS_TARGET_ROOT="${_NDS_TARGET_ROOT:-/mnt}"

eventCreate cook.pre_disk
eventCreate cook.post_disk
eventCreate cook.pre_install
eventCreate cook.post_install
eventCreate cook.done

_cook_step() {
    local _cook_label=$1
    shift
    taskSpin "$_cook_label"
    if "$@"; then
        taskOk
        return 0
    fi
    taskFail
    if declare -f nds_diagnose_append >/dev/null; then
        nds_diagnose_append "step failed: ${_cook_label}" || true
    fi
    return 1
}

_nds_cook_enableSections() {
    local _cook_file=$1 _cook_line _cook_group
    nds_schema_enable cook || return 1
    while IFS= read -r _cook_line || [[ -n "$_cook_line" ]]; do
        [[ "$_cook_line" == \[*\] ]] || continue
        _cook_group=${_cook_line#"["}
        _cook_group=${_cook_group%"]"}
        [[ -n "$_cook_group" ]] || continue
        nds_schema_enable "$_cook_group" || return 1
    done < "$_cook_file"
}

_nds_cook_unlock() {
    local _cook_key
    local -a _cook_locked=()
    for _cook_key in "${!_NDS_SCHEMA_ATTR[@]}"; do
        [[ "$_cook_key" == *'|locked' ]] || continue
        _cook_locked+=("$_cook_key")
    done
    for _cook_key in "${_cook_locked[@]+"${_cook_locked[@]}"}"; do
        unset "_NDS_SCHEMA_ATTR[$_cook_key]"
    done
}

_cook_phase_region() {
    case "$1" in
        leaf_push|disk) printf '%s\n' disk ;;
        write_classic|hardware_nix|copy_configs|stage_flake|hardware_facter|write_generated_host|host_structure|stage_host_files|prefetch|eval)
            printf '%s\n' config
            ;;
        install_classic|install_flake|install_anywhere) printf '%s\n' install ;;
        seed|seed_git|sops) printf '%s\n' settle ;;
        bootloader|verify) printf '%s\n' finish ;;
        *) return 1 ;;
    esac
}

_cook_run_phase() {
    local _cook_name=$1 _cook_phase=$2
    local -n _R=$1
    local _cook_cfg _cook_install _cook_host _cook_rel _cook_host_dir _cook_secrets _cook_place _cook_dest
    local -a _cook_extra=()
    _cook_host=${_R[FLAKE_HOST]:-}
    _cook_secrets="${ nds_session_dir secrets; }"
    _cook_cfg="${ nds_session_dir config; }"
    if [[ ${_R[INSTALL_MODE]:-local} == remote ]]; then
        _cook_install="${ nds_session_dir work; }/flake-stage"
    else
        _cook_install=${_R[FLAKE_INSTALL_PATH]:-${_NDS_TARGET_ROOT}/etc/nixos}
    fi
    _cook_rel=${_R[FLAKE_HOST_DIR]:-hosts/x86_64-linux}
    _cook_host_dir="${_cook_install}/${_cook_rel}/${_cook_host}"
    case "$_cook_phase" in
        leaf_push) _cook_step "Leaf push" step_leafPush "$_cook_name" || return 1 ;;
        disk) _cook_step "Disk" step_disk "$_cook_name" || return 1 ;;
        write_classic)
            _cook_step "Configuration" nixcfg_writeClassic "$_cook_name" "${_cook_cfg}/configuration.nix" || return 1
            ;;
        hardware_nix)
            _cook_dest="${_NDS_TARGET_ROOT}/etc/nixos/hardware-configuration.nix"
            _cook_step "Generate hardware-configuration.nix" step_hardware_nix "$_cook_dest" "$_cook_cfg" || return 1
            ;;
        copy_configs)
            _cook_step "Copy configuration" nixos_copyConfigs "$_cook_cfg" "$_NDS_TARGET_ROOT" || return 1
            ;;
        stage_flake) _cook_step "Stage flake" step_stageFlake "$_cook_name" "$_cook_install" || return 1 ;;
        hardware_facter)
            _cook_place=${_R[FLAKE_HARDWARE_PLACEMENT]:-host-dir}
            if [[ "$_cook_place" == etc-nixos ]]; then
                _cook_dest="${_NDS_TARGET_ROOT}/etc/nixos/facter.json"
            else
                _cook_dest="${_cook_host_dir}/facter.json"
            fi
            _cook_step "Generate facter.json" step_hardware_facter "$_cook_dest" "$_cook_cfg" || return 1
            ;;
        write_generated_host)
            _cook_step "Generated host" nixcfg_writeGeneratedHost "$_cook_name" "$_cook_host_dir" || return 1
            ;;
        host_structure) _cook_step "Host structure" flake_hostStructureOk "$_cook_host_dir" || return 1 ;;
        stage_host_files)
            _cook_step "Stage host files" flake_gitStageHostFiles "$_cook_install" "$_cook_host_dir" \
                nds_generated.nix configuration.nix || return 1
            ;;
        prefetch) _cook_step "Prefetch" nixos_prefetchFlake "$_cook_install" "${_R[GIT_KEYS_DIR]:-}" || return 1 ;;
        eval) _cook_step "Eval" nixos_flakeEval "$_cook_install" "$_cook_host" || return 1 ;;
        install_classic) _cook_step "Install" nixos_installClassic "$_NDS_TARGET_ROOT" || return 1 ;;
        install_flake)
            _cook_step "Install" nixos_installFlake "$_cook_install" "$_cook_host" "$_cook_host_dir" \
                "${_R[FLAKE_HARDWARE_PLACEMENT]:-host-dir}" || return 1
            ;;
        install_anywhere)
            mapfile -t _cook_extra < <(step_seedRemoteArgs "$_cook_name")
            if [[ -n ${_R[ENCRYPTION_KEY_FILE]:-} ]]; then
                _cook_extra+=(--key-file "${_R[ENCRYPTION_KEY_FILE]}")
            fi
            _cook_step "Install" nixos_anywhere "$_cook_install" "$_cook_host" \
                "${_R[REMOTE_TARGET_IP]}" "${_cook_install}/facter.json" "${_R[ENCRYPTION_KEY_FILE]:-}" \
                ${_cook_extra[@]+"${_cook_extra[@]}"} || return 1
            ;;
        seed) _cook_step "Seed" step_seed "$_cook_name" || return 1 ;;
        seed_git) _cook_step "Git keys" step_seedGit "$_cook_name" || return 1 ;;
        sops)
            _cook_step "Sops" sops_installKey "${_R[SOPS_AGE_KEY_FILE]}" "$_NDS_TARGET_ROOT" "$_cook_secrets" "$_cook_host" || return 1
            ;;
        bootloader) _cook_step "Bootloader" step_bootloader "$_cook_name" || return 1 ;;
        verify) _cook_step "Verify" nds_cook_verify "$_cook_name" || return 1 ;;
        *)
            error "COOK_PHASES: unknown ${_cook_phase}"
            return 1
            ;;
    esac
}

_cook_run_region() {
    local _cook_name=$1 _cook_region=$2 _cook_list=$3 _cook_phase _cook_got
    local -a _cook_ordered=()
    [[ -n "$_cook_list" ]] || return 0
    read -ra _cook_ordered <<< "${_cook_list}"
    for _cook_phase in "${_cook_ordered[@]+"${_cook_ordered[@]}"}"; do
        _cook_got=${ _cook_phase_region "$_cook_phase"; } || return 1
        [[ "$_cook_got" == "$_cook_region" ]] || continue
        _cook_run_phase "$_cook_name" "$_cook_phase" || return 1
    done
}

nds_cook_run() {
    local -n R=$1
    local _cook_list=$2
    nds_cook_preflight "$1"
    debug "Cook phases ${_cook_list:-<none>}"
    debug "Target root ${_NDS_TARGET_ROOT}"
    nixos_setBootContext "${R[BOOT_LOADER]:-grub}" "${R[BOOT_UEFI_MODE]:-}" \
        "${R[DISK_TARGET]:-}" "${R[ENCRYPTION]:-false}"
    eventRun cook.pre_disk "$1"
    _cook_run_region "$1" disk "$_cook_list"
    eventRun cook.post_disk "$1"
    _cook_run_region "$1" config "$_cook_list"
    eventRun cook.pre_install "$1"
    _cook_run_region "$1" install "$_cook_list"
    _cook_run_region "$1" settle "$_cook_list"
    eventRun cook.post_install "$1"
    _cook_run_region "$1" finish "$_cook_list"
    eventRun cook.done "$1"
}

nds_install_classic() {
    nds_cook_run "$1" "disk write_classic hardware_nix copy_configs install_classic bootloader verify"
}

nds_install_flake() {
    local _ins_mode
    _ins_mode=$(nds_recipe_get "$1" INSTALL_MODE)
    if [[ "$_ins_mode" == remote ]]; then
        nds_cook_run "$1" "stage_flake prefetch eval install_anywhere"
        return
    fi
    local _ins_list="disk stage_flake"
    [[ $(nds_recipe_get "$1" FLAKE_HARDWARE_PLACEMENT) == skip ]] || _ins_list+=" hardware_facter"
    _ins_list+=" write_generated_host host_structure stage_host_files prefetch eval install_flake"
    nds_recipe_has "$1" TARGET_SEED_DIR && _ins_list+=" seed"
    nds_recipe_has "$1" GIT_KEYS_DIR && [[ $(nds_recipe_get "$1" GIT_PERSIST_ACCESS) == true ]] && _ins_list+=" seed_git"
    nds_recipe_has "$1" SOPS_AGE_KEY_FILE && _ins_list+=" sops"
    _ins_list+=" bootloader verify"
    nds_cook_run "$1" "$_ins_list"
}

nds_leaf_push() {
    nds_recipe_has "$1" LEAF_PUSH_DIR || return 0
    step_leafPush "$1"
}

nds_cook() {
    local -A R=()
    local _cook_file=$1 _cook_n=0
    local _cook_list
    _nds_cook_unlock
    _nds_cook_enableSections "$_cook_file" || return 1
    nds_recipe_loadFile R "$_cook_file" || return 1
    nds_recipe_validate R || _cook_n=$?
    if (( _cook_n != 0 )); then
        return 1
    fi
    nds_cook_preflight R || return 1
    _cook_list=${R[COOK_PHASES]:-}
    debug "Cook phases ${_cook_list:-<none>}"
    debug "Target root ${_NDS_TARGET_ROOT}"
    nixos_setBootContext "${R[BOOT_LOADER]:-grub}" "${R[BOOT_UEFI_MODE]:-}" \
        "${R[DISK_TARGET]:-}" "${R[ENCRYPTION]:-false}"
    eventRun cook.pre_disk R || return 1
    _cook_run_region R disk "$_cook_list" || return 1
    eventRun cook.post_disk R || return 1
    _cook_run_region R config "$_cook_list" || return 1
    eventRun cook.pre_install R || return 1
    _cook_run_region R install "$_cook_list" || return 1
    _cook_run_region R settle "$_cook_list" || return 1
    eventRun cook.post_install R || return 1
    _cook_run_region R finish "$_cook_list" || return 1
    eventRun cook.done R || return 1
}
