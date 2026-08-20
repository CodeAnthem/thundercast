#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install bundle finish screens
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-30 | Modified: 2026-08-19
# Description:   Backup zip confirm, copy/USB hints, reboot offer
# ==================================================================================================

declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_BACKUP_CONFIRM_SKIP
declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_REBOOT_SKIP

_nds_bundle_ui_colored() {
    local color="$1"
    local text="$2"
    nds_ui_init
    if [[ "$NDS_UI_COLOR" == true ]]; then
        printf '%s\033[%sm%s\033[0m\n' "$NDS_UI_INDENT_B" "$color" "$text" >&2
    else
        printf '%s%s\n' "$NDS_UI_INDENT_B" "$text" >&2
    fi
}

_nds_bundle_remote_copy_hint() {
    local bundle_path="$1"
    local ssh_user host local_name

    ssh_user=$(nds_lib_getSshUser)
    host=$(nds_lib_getHostIP)
    [[ -z "$host" ]] && return 0

    local_name=$(nds_bundle_local_name)
    [[ "$bundle_path" == *.tar.gz ]] && local_name="${local_name%.zip}.tar.gz"

    nds_ui_b "Backup it from your local machine:"
    nds_ui_i "SCP:"
    nds_ui_i "  scp ${ssh_user}@${host}:${bundle_path} ./${local_name}"
    nds_ui_b ""
    nds_ui_i "SSH:"
    nds_ui_i "  ssh ${ssh_user}@${host} \"cat ${bundle_path}\" > ${local_name}"
    nds_ui_b ""
}

_nds_bundle_usbkey_instructions() {
    _nds_install_gather_context
    [[ "$NDS_CTX_ENCRYPTION" == "true" ]] || return 0
    [[ "$NDS_CTX_ENCRYPTION_KEY" == "true" ]] || return 0

    nds_ui_b ""
    nds_ui_h "Prepare your USB key (required to boot)"
    nds_ui_i "The LUKS key is in this zip at secrets/luks_key.bin."

    if [[ -z "$NDS_CTX_KEY_BOOT_FILE" ]]; then
        nds_ui_i "Copy it to a USB stick as RAW bytes BEFORE rebooting:"
        nds_ui_i "  dd if=luks_key.bin of=<usb-device> bs=4096 count=1"
        nds_ui_i "Plug that USB in at every boot. Its device path must match:"
        nds_ui_i "  ENCRYPTION_KEY_BOOT_DEVICE = ${NDS_CTX_KEY_BOOT_DEVICE}"
    else
        nds_ui_i "Copy it to a file on a USB stick BEFORE rebooting:"
        nds_ui_i "  mount <usb-device> /mnt/usb"
        nds_ui_i "  cp luks_key.bin /mnt/usb/${NDS_CTX_KEY_BOOT_FILE}"
        nds_ui_i "  umount /mnt/usb"
        nds_ui_i "Plug that USB in at every boot. Its device path must match:"
        nds_ui_i "  ENCRYPTION_KEY_BOOT_DEVICE = ${NDS_CTX_KEY_BOOT_DEVICE}"
    fi

    if [[ "$NDS_CTX_ENCRYPTION_PASSWORD" != "true" ]]; then
        nds_ui_b ""
        _nds_bundle_ui_colored 31 "WARNING: key-only mode (no password)."
        _nds_bundle_ui_colored 31 "If this USB is lost, stolen, or corrupted, the system CANNOT boot."
        _nds_bundle_ui_colored 31 "There is no fallback. Consider re-installing with a password too."
    fi
}

# Description: Create the install backup zip and show copy / USB / reboot screens.
# Returns:
# - <Bool> 0 on success
nds_bundle_finish() {
    local bundle_ok=1
    nds_bundle_create || bundle_ok=0

    if [[ "$bundle_ok" -ne 0 && -n "${NDS_INSTALL_BUNDLE:-}" && -f "$NDS_INSTALL_BUNDLE" ]]; then
        _nds_install_gather_context
        nds_ui_section_header "Backup bundle"
        nds_ui_indent_push
        nds_ui_h "Save the restore package for future use"
        nds_ui_b "Copy this zip off the machine before you reboot."
        nds_ui_b "It includes your NDS configuration, install logs, and unlock material (if encrypted)."
        nds_ui_b ""

        if [[ "$NDS_CTX_ENCRYPTION" == "true" ]]; then
            _nds_bundle_ui_colored 35 "Encryption was enabled — saving this zip is important."
            _nds_bundle_ui_colored 35 "Keep it somewhere safe and offline; it contains your unlock secrets."
            nds_ui_b ""
        fi

        _nds_bundle_usbkey_instructions
        _nds_bundle_remote_copy_hint "$NDS_INSTALL_BUNDLE"
        nds_ui_indent_pop

        if nds_skip_menu NDS_BACKUP_CONFIRM_SKIP; then
            nds_log_from_env "Backup copy confirmation skipped"
        else
            nds_ask_user_to_proceed "I have copied the package (or do not need it)" || return 1
        fi

        nds_ui_b ""
        nds_ui_h "Next steps"
        nds_ui_b "Personalized first-login and remote-unlock instructions are in the bundle:"
        nds_ui_i "QUICK_START.md  (at the root of the zip)"
        nds_ui_b "Online guide:"
        if declare -f _nds_bundle_action_readme_url &>/dev/null; then
            nds_ui_i "$(_nds_bundle_action_readme_url)"
        else
            nds_ui_i "https://github.com/CodeAnthem/thundercast/blob/main/src/actions/classicInstall/README.md"
        fi
        nds_ui_b ""
        _nds_bundle_offer_reboot
        return 0
    fi

    if [[ "$bundle_ok" -ne 0 ]]; then
        warn "Install backup package could not be created — fix verification issues before rebooting."
    fi
    nds_ui_b ""
    _nds_bundle_offer_reboot
    return 0
}

# Unattended never reboots unless NDS_REBOOT_FORCE=true (bundle has secrets/passwords).
# Interactive: prompt, unless NDS_REBOOT_SKIP.
# The reboot command line is printed last (after session cleanup).
_nds_bundle_offer_reboot() {
    nds_mode_resolve || true
    if declare -f nds_mode_is_unattended &>/dev/null && nds_mode_is_unattended; then
        if declare -f nds_unattended_wants_reboot &>/dev/null && nds_unattended_wants_reboot; then
            nds_log_from_env "Rebooting (NDS_REBOOT_FORCE)"
            NDS_REBOOT_IN_PROGRESS=1
            reboot
        else
            NDS_REBOOT_HINT_PENDING=1
        fi
        return 0
    fi
    if nds_skip_menu NDS_REBOOT_SKIP; then
        nds_log_from_env "Reboot prompt skipped"
        NDS_REBOOT_HINT_PENDING=1
        return 0
    fi
    if nds_ask_user_to_proceed "Reboot now?"; then
        NDS_REBOOT_IN_PROGRESS=1
        reboot
    else
        NDS_REBOOT_HINT_PENDING=1
    fi
    return 0
}

# Description: Print the reboot command after session cleanup (last console line).
nds_bundle_print_reboot_hint() {
    [[ "${NDS_REBOOT_HINT_PENDING:-}" == "1" ]] || return 0
    NDS_REBOOT_HINT_PENDING=0
    nds_ui_b "Reboot when ready: sudo reboot"
}

# Description: Classic-install wrapper: unmute UI and run bundle finish.
# Returns:
# - <Bool> 0 on success
nds_install_finish() {
    NDS_UI_QUIET=false
    nds_bundle_finish || return 1
    return 0
}

# Description: Remote-install finish: backup zip plus nixos-anywhere next-step hints.
# Returns:
# - <Bool> 0
nds_install_remote_finish() {
    local bundle_ok=1
    NDS_UI_QUIET=false
    nds_bundle_create || bundle_ok=0

    nds_ui_section_header "Remote install complete"
    nds_ui_h "Next steps"
    nds_ui_b "nixos-anywhere reboots the target host when finished."
    nds_ui_b "Commit the generated facter.json in your flake host directory."
    nds_ui_b "Enroll the machine age key in .sops.yaml, then run sops updatekeys on the split secret files"
    nds_ui_b ""

    if [[ "$bundle_ok" -ne 0 && -n "${NDS_INSTALL_BUNDLE:-}" && -f "$NDS_INSTALL_BUNDLE" ]]; then
        nds_ui_i "Install backup: ${NDS_INSTALL_BUNDLE}"
        _nds_bundle_remote_copy_hint "$NDS_INSTALL_BUNDLE"
    fi

    return 0
}
