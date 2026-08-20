#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install confirmation screen
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-08-16
# Description:   Local/remote install confirm plus overwrite prompts
# ==================================================================================================
declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_INSTALL_CONFIRM_SKIP

# Description: Show the pre-install warning screen.
# Arguments:
# - disk:     <String> Target block device
# - strategy: <String|optional> Partitioning strategy label (default: nds)
# - extra:    <String|optional> Extra message line
nds_install_ui_show_warning() {
    local disk="$1"
    local strategy="${2:-nds}"
    local extra="${3:-}"
    local strategy_label mode
    local flake_host flake_path flake_source install_mode

    case "$strategy" in
        nds)
            mode=$(nds_cfg_get "BOOT_UEFI_MODE" 2>/dev/null || true)
            if [[ "$mode" == "true" ]]; then
                strategy_label='NDS built-in partitioning (UEFI + root)'
            else
                strategy_label='NDS built-in partitioning (BIOS + root)'
            fi
            ;;
        disko) strategy_label='Disko template' ;;
        flake) strategy_label='No NDS partitioning (your flake owns disk)' ;;
        *) strategy_label="$strategy" ;;
    esac

    nds_ui_section_header "Ready to install"
    nds_ui_b "Review the summary below. Installation does not start until you confirm at the end."
    nds_ui_b ""

    flake_host="${NDS_FLAKE_HOST:-$(nds_cfg_get FLAKE_HOST 2>/dev/null || true)}"
    flake_path="${NDS_FLAKE_INSTALL_PATH:-$(nds_cfg_get FLAKE_INSTALL_PATH 2>/dev/null || true)}"
    flake_path="${flake_path:-/mnt/etc/nixos}"
    flake_source="${NDS_FLAKE_SOURCE:-$(nds_cfg_get FLAKE_SOURCE 2>/dev/null || true)}"
    install_mode="${NDS_INSTALL_MODE:-$(nds_cfg_get INSTALL_MODE 2>/dev/null || true)}"
    install_mode="${install_mode:-local}"
    if [[ -n "$flake_host" ]]; then
        nds_ui_h "Flake target"
        nds_ui_i "${flake_path}#${flake_host} (source: ${flake_source:-remote}, mode: ${install_mode})"
        nds_ui_b ""
    fi

    nds_ui_h "Target disk"
    if [[ "$NDS_UI_COLOR" == true ]]; then
        nds_ui_i "$(printf '%s\033[31;1m — all data will be permanently erased\033[0m' "$disk")"
    else
        nds_ui_i "${disk} — all data will be permanently erased"
    fi
    nds_ui_b ""

    nds_ui_h "Partitioning"
    nds_ui_i "$strategy_label"
    nds_ui_b ""

    nds_ui_h "Steps"
    case "$strategy" in
        flake)
            nds_ui_i "1. Verify /mnt is already mounted (NDS does not partition)"
            nds_ui_i "2. Generate facter.json on the live system (nixos-facter)"
            nds_ui_i "3. Run nixos-install from your flake (Nix downloads and builds packages)"
            nds_ui_i "4. Offer an install backup zip (config and logs)"
            ;;
        *)
            nds_ui_i "1. Partition and format ${disk} (LUKS2 if encryption is enabled)"
            nds_ui_i "2. Generate facter.json on the live system (nixos-facter)"
            nds_ui_i "3. Run nixos-install — Nix downloads and builds packages"
            nds_ui_i "4. Offer an install backup zip (config, logs, and encryption keys if encrypted)"
            ;;
    esac
    nds_ui_b ""

    [[ -n "$extra" ]] && nds_ui_b "$extra" && nds_ui_b ""
}

# Description: Show the install warning screen and ask the user to confirm.
# Arguments:
# - disk:     <String> Target block device
# - strategy: <String|optional> Partitioning strategy label
# - extra:    <String|optional> Extra message line
nds_install_ui_confirm_install() {
    local disk="$1"
    local strategy="${2:-nds}"
    local extra="${3:-}"

    nds_mode_resolve || true
    if nds_skip_menu NDS_INSTALL_CONFIRM_SKIP \
        || { declare -f nds_mode_is_unattended &>/dev/null && nds_mode_is_unattended; }; then
        nds_log_from_env "Install confirmation skipped (${disk})"
        return 0
    fi
    nds_install_ui_show_warning "$disk" "$strategy" "$extra"
    nds_ask_user_to_proceed "Start installation now" || return 1
    return 0
}

# --- overwrite / section helpers (was install_confirm_prompts.sh) ---
declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_HARDWARE_OVERWRITE_SKIP
declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_SCAFFOLD_OVERWRITE_SKIP

# Description: Section header for flake access verification.
nds_install_ui_section_flake_access() {
    nds_ui_section_header "Verifying flake access"
}

# Description: Confirm overwrite of an existing hardware artifact.
# Arguments:
# - artifact: <String> Filename (e.g. facter.json)
# Returns:
# - 0 when overwrite allowed; 1 when keep existing
nds_install_ui_confirm_hardware_overwrite() {
    local artifact="$1"
    if nds_skip_menu NDS_HARDWARE_OVERWRITE_SKIP; then
        return 0
    fi
    nds_ask_user_to_proceed "Overwrite existing ${artifact}?"
}

# Description: Confirm overwrite of files in a host directory.
# Arguments:
# - host_dir: <String> Absolute host dir path
nds_install_ui_confirm_scaffold_overwrite() {
    local host_dir="$1"
    if nds_skip_menu NDS_SCAFFOLD_OVERWRITE_SKIP; then
        return 0
    fi
    nds_ask_user_to_proceed "Overwrite files in ${host_dir}?"
}

# Description: Section header for the NixOS install phase.
nds_install_ui_section_nixos_install() {
    nds_ui_section_header "NixOS installation"
}

# --- remote confirm (was install_remote_confirm.sh) ---
declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_REMOTE_CONFIRM_SKIP


# Description: Show the remote install warning screen and ask the user to confirm.
# Arguments:
# - target_ip: <String> Remote host IP or hostname
# - extra:     <String|optional> Extra message line
nds_install_ui_confirm_remote() {
    local target_ip="$1"
    local extra="${2:-}"
    local flake_host flake_path flake_source

    nds_mode_resolve || true
    if nds_skip_menu NDS_REMOTE_CONFIRM_SKIP \
        || { declare -f nds_mode_is_unattended &>/dev/null && nds_mode_is_unattended; }; then
        nds_log_from_env "Remote install confirmation skipped (${target_ip})"
        return 0
    fi

    nds_ui_section_header "Ready to install (remote)"
    nds_ui_b "Review the summary below. Installation does not start until you confirm at the end."
    nds_ui_b ""

    flake_host="${NDS_FLAKE_HOST:-$(nds_cfg_get FLAKE_HOST 2>/dev/null || true)}"
    flake_path="${NDS_FLAKE_INSTALL_PATH:-$(nds_cfg_get FLAKE_INSTALL_PATH 2>/dev/null || true)}"
    flake_path="${flake_path:-/mnt/etc/nixos}"
    flake_source="${NDS_FLAKE_SOURCE:-$(nds_cfg_get FLAKE_SOURCE 2>/dev/null || true)}"
    if [[ -n "$flake_host" ]]; then
        nds_ui_h "Flake target"
        nds_ui_i "${flake_path}#${flake_host} (source: ${flake_source:-remote}, mode: remote)"
        nds_ui_b ""
    fi

    nds_ui_h "Target host"
    nds_ui_i "root@${target_ip} — disk will be partitioned and all data erased"
    nds_ui_b ""

    nds_ui_h "Steps"
    nds_ui_i "1. Clone or use your flake on this machine"
    nds_ui_i "2. Run nixos-anywhere (disko + nixos-facter + install)"
    nds_ui_i "3. Commit generated facter.json to your flake repo"
    nds_ui_b ""

    [[ -n "$extra" ]] && nds_ui_b "$extra" && nds_ui_b ""

    nds_ask_user_to_proceed "Start remote installation now" || return 1
    return 0
}
