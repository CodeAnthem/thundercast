#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install confirm
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Wipe and remote confirm. The pipeline skips this when install.confirm is skipped.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_skip_register install.confirm "proceed without the wipe confirm"

_nds_confirm_display() {
    local _con_key=$1 _con_value=$2 _con_type _con_labels _con_pair
    local -a _con_parts=()
    _con_type=${_NDS_SCHEMA_FIELD_TYPE[$_con_key]:-}
    if [[ "$_con_type" == secret && -n "$_con_value" ]]; then
        printf '%s' '(file)'
        return 0
    fi
    if [[ "$_con_type" == choice && -n "$_con_value" ]]; then
        _con_labels=$(nds_schema_attr "$_con_key" labels)
        IFS='|' read -ra _con_parts <<< "$_con_labels"
        for _con_pair in "${_con_parts[@]}"; do
            if [[ "${_con_pair%%=*}" == "$_con_value" ]]; then
                printf '%s' "${_con_pair#*=}"
                return 0
            fi
        done
    fi
    printf '%s' "$_con_value"
}

_nds_confirm_groups() {
    local _con_name=$1 _con_group _con_key _con_value
    local -n _con_R=$1
    while IFS= read -r _con_group; do
        [[ -n "$_con_group" ]] || continue
        nds_schema_groupIsActive "$_con_name" "$_con_group" || continue
        ui_h "${_NDS_SCHEMA_GROUP_TITLE[$_con_group]:-$_con_group}"
        while IFS= read -r _con_key; do
            [[ -n "$_con_key" ]] || continue
            nds_schema_isActive "$_con_name" "$_con_key" || continue
            _con_value=$(_nds_confirm_display "$_con_key" "${_con_R[$_con_key]:-}")
            ui_kv "$(nds_schema_attr "$_con_key" label)" "$_con_value"
        done < <(nds_schema_groupFields "$_con_group")
    done < <(nds_schema_groups)
}

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
    _nds_confirm_groups R
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
    done < <(nds_cook_preflight --warnings R)
    prompt --type confirm "Start installation now" || _con_rc=$?
    [[ "$_con_rc" -eq 0 && "$UI_PROMPT_RESULT" == y ]] || return 1
    info "Installation confirmed — starting now"
}
