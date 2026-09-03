#!/usr/bin/env bash
# ==================================================================================================
# NDS realize - boot steps (EFI NVRAM entry) and access secrets
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-30 | Modified: 2026-09-03
# ==================================================================================================

# Description: UEFI decision: BOOT_UEFI_MODE when set, else live firmware.
# Arguments:
# - uefi: <String> true | false | ""
_nds_realize_is_uefi() {
    case "${1:-}" in
        true) return 0 ;;
        false) return 1 ;;
        *) [[ -d /sys/firmware/efi/efivars ]] ;;
    esac
}

# Description: Register the NixOS EFI entry (nixos-install's chroot bootctl cannot write NVRAM).
# No-op for BIOS installs.
# Arguments:
# - disk:   <String> Target block device (ESP is partition 1)
# - uefi:   <String> BOOT_UEFI_MODE
# - loader: <String> BOOT_LOADER id
_nds_realize_register_efi() {
    local disk="$1" uefi="$2" loader="${3:-systemd-boot}"
    local loader_path

    _nds_realize_is_uefi "$uefi" || return 0
    nds_requireUtility disk || return 1
    loader_path=${ disk_efiLoaderPath "$loader"; }
    if ! disk_efiRegister "$disk" "$loader_path" NixOS; then
        error "Could not register the EFI boot entry (${loader_path} on ${disk}1)"
        error "Boot the ISO in UEFI mode, or pick a BIOS bootloader (GRUB)"
        return 1
    fi
    log "Registered EFI boot entry: NixOS -> ${loader_path}"
    nds_install_log "EFI boot entry registered for ${disk}1 (${loader_path})"
    return 0
}

# Description: Resolve the admin password (settings or secret store) and write it for nixcfg.
# Arguments:
# - secrets_dir: <String> Runtime secrets directory
_nds_realize_write_admin_password() {
    local secrets_dir="$1" manual

    nds_requireUtility nixcfg || return 1
    manual="$(nds_cfg_get ACCESS_ADMIN_PASSWORD)"
    if [[ -z "$manual" ]] && declare -f nds_sm_secret_read &>/dev/null; then
        manual="${ nds_sm_secret_read ACCESS_ADMIN_PASSWORD; }"
    fi
    nds_nixcfg_write_admin_password \
        "$(nds_cfg_get ACCESS_ADMIN_PASSWORD_AUTO)" "$(nds_cfg_get ACCESS_ADMIN_PASSWORD_LENGTH)" \
        "$manual" "$secrets_dir" || return 1
    nds_install_log "Generated admin password (saved to secrets/admin_password.txt)"
    return 0
}
