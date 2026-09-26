#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install confirm
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Wipe and remote confirm. The pipeline skips this when install.confirm is skipped.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_skip_register install.confirm "proceed without the wipe confirm"

_nds_confirm_strategy() {
    local _con_strategy=$1 _con_uefi=$2
    case "$_con_strategy" in
        nds)
            if [[ "$_con_uefi" == true ]]; then
                printf '%s\n' "NDS built-in partitioning (UEFI + root)"
            else
                printf '%s\n' "NDS built-in partitioning (BIOS + root)"
            fi
            ;;
        disko) printf '%s\n' "Disko template" ;;
        flake) printf '%s\n' "No NDS partitioning (your flake owns disk)" ;;
        *) printf '%s\n' "$_con_strategy" ;;
    esac
}

nds_confirm() {
    local _con_file=$1
    local -A R=()
    local _con_line _con_rc=0 _con_strategy _con_mode _con_host _con_path _con_source
    nds_schema_enableAll || return 1
    nds_recipe_loadFile R "$_con_file" || return 1
    _con_mode=${R[INSTALL_MODE]:-local}
    _con_strategy=${R[DISK_STRATEGY]:-nds}
    _con_host=${R[FLAKE_HOST]:-}
    _con_path=${R[FLAKE_INSTALL_PATH]:-/mnt/etc/nixos}
    _con_source=${R[FLAKE_SOURCE]:-remote}
    if [[ "$_con_mode" == remote ]]; then
        ui_h "Ready to install (remote)"
    else
        ui_h "Ready to install"
    fi
    ui_b "Review the summary below. Installation does not start until you confirm at the end."
    if [[ -n "$_con_host" ]]; then
        ui_h "Flake target"
        ui_i "${_con_path}#${_con_host} (source: ${_con_source}, mode: ${_con_mode})"
    fi
    if [[ "$_con_mode" == remote ]]; then
        ui_h "Target host"
        ui_i "root@${R[REMOTE_TARGET_IP]} — disk will be partitioned and all data erased"
        ui_h "Steps"
        ui_i "1. Clone or use your flake on this machine"
        ui_i "2. Run the remote installer (disko, hardware facts, install)"
        ui_i "3. Commit generated hardware facts to your flake repo"
    else
        ui_h "Target disk"
        ui_i "${R[DISK_TARGET]:-(flake owns the disk)} — all data will be permanently erased"
        ui_h "Partitioning"
        ui_i "${ _nds_confirm_strategy "$_con_strategy" "${R[BOOT_UEFI_MODE]:-}"; }"
        ui_h "Steps"
        if [[ "$_con_strategy" == flake ]]; then
            ui_i "1. Verify /mnt is already mounted (NDS does not partition)"
            ui_i "2. Generate hardware facts on the live system"
            ui_i "3. Install NixOS from your flake"
            ui_i "4. Offer an install backup zip (config and logs)"
        else
            ui_i "1. Partition and format ${R[DISK_TARGET]:-the disk} (LUKS2 if encryption is enabled)"
            ui_i "2. Generate hardware facts on the live system"
            ui_i "3. Install NixOS"
            ui_i "4. Offer an install backup zip (config, logs, and encryption keys if encrypted)"
        fi
    fi
    while IFS= read -r _con_line; do
        [[ -n "$_con_line" ]] && ui_b "$_con_line"
    done < <(nds_realize_preflight --warnings R)
    prompt --type confirm "Start installation now" || _con_rc=$?
    [[ "$_con_rc" -eq 0 && "$UI_PROMPT_RESULT" == y ]] || return 1
    info "Installation confirmed — starting now"
}
