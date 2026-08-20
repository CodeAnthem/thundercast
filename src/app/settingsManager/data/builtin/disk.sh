#!/usr/bin/env bash
# ==================================================================================================
# NDS - Disk preset
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-03
# ==================================================================================================

disk_defaults() {
    local first_disk
    first_disk=$(find /dev \( -name 'sd[a-z]' -o -name 'nvme[0-9]*n[0-9]*' -o -name 'vd[a-z]' \) 2>/dev/null | sort | head -n1)
    nds_cfg_set DISK_TARGET "${first_disk:-}"
    nds_cfg_set DISK_STRATEGY "nds"
    nds_cfg_set DISK_FS_TYPE "ext4"
    nds_cfg_set DISK_SWAP_SIZE_MIB "0"
    nds_cfg_set DISK_DISKO_CONFIG ""
}

disk_configure() {
    nds_cfg_section_title "Disk"
    nds_cfg_ask_disk DISK_TARGET "Target disk"
    nds_cfg_ask_choice DISK_STRATEGY "Partitioning method" "nds|disko|flake" \
        "nds=NDS built-in (UEFI or BIOS)|disko=Disko template|flake=Your flake (NDS skips disk)" "nds"
    if nds_cfg_is DISK_STRATEGY disko; then
        nds_cfg_ask_choice DISK_FS_TYPE "Root filesystem" "ext4|btrfs" "" "ext4"
        nds_cfg_ask_int DISK_SWAP_SIZE_MIB "Swap size (MiB, 0=none)" 0 0 65536
        nds_cfg_ask_path DISK_DISKO_CONFIG "Disko config file (optional)" "" false
    fi
}

disk_summary() {
    nds_cfg_summary_row "Target disk" "$(nds_cfg_get DISK_TARGET)"
    nds_cfg_summary_row "Partitioning" "$(nds_cfg_display_choice "$(nds_cfg_get DISK_STRATEGY)" "nds=NDS built-in|disko=Disko|flake=Flake owns disk")"
    if nds_cfg_is DISK_STRATEGY disko; then
        nds_cfg_summary_row "Root filesystem" "$(nds_cfg_get DISK_FS_TYPE)"
        nds_cfg_summary_row "Swap (MiB)" "$(nds_cfg_get DISK_SWAP_SIZE_MIB)"
        local dc; dc=$(nds_cfg_get DISK_DISKO_CONFIG)
        [[ -n "$dc" ]] && nds_cfg_summary_row "Disko config" "$dc"
    fi
    return 0
}

disk_prompt_errors() {
    nds_cfg_section_title "Disk"
    while ! disk_validate &>/dev/null; do
        if [[ -z "$(nds_cfg_get DISK_TARGET)" ]] || ! validate_disk "$(nds_cfg_get DISK_TARGET)" 2>/dev/null; then
            nds_cfg_ask_disk DISK_TARGET "Target disk"
            continue
        fi
        break
    done
}

disk_validate() {
    [[ -n "$(nds_cfg_get DISK_TARGET)" ]] || { validation_error "Target disk is required"; return 1; }
    validate_disk "$(nds_cfg_get DISK_TARGET)" || { validation_error "Invalid target disk"; return 1; }
    return 0
}

if declare -f nds_preset_register_hooks &>/dev/null; then
    nds_preset_register_hooks \
        defaults=disk_defaults \
        configure=disk_configure \
        validate=disk_validate \
        summary=disk_summary \
        prompt_errors=disk_prompt_errors
fi

NDS_PRESET_PRIORITY=20
NDS_PRESET_DISPLAY="Disk"
