#!/usr/bin/env bash
# ==================================================================================================
# NDS - Disk format and encryption prompts
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-08-20
# Description:   Confirm wipe + LUKS password/keyfile collection
# ==================================================================================================
declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_DISK_FORMAT_CONFIRM_SKIP

# Description: Show disk layout and confirm format when needed.
# Arguments:
# - disk:  <String> Target disk
# - state: <String> wiped|empty_parts|has_fs|in_use|…
# Returns:
# - 0 when format may proceed
nds_install_ui_confirm_disk_format() {
    local disk="$1" state="$2"

    nds_ui_section_header "Current Disk Layout"
    declare -f _nds_install_partition_summarize_disk &>/dev/null \
        && _nds_install_partition_summarize_disk "$disk"

    case "$state" in
        wiped|empty_parts) return 0 ;;
        has_fs|in_use)
            warn "Detected existing filesystems or mounted partitions on $disk"
            if nds_skip_menu NDS_DISK_FORMAT_CONFIRM_SKIP \
                || nds_skip_menu NDS_INSTALL_CONFIRM_SKIP; then
                return 0
            fi
            nds_ask_user_to_proceed "Formatting will DESTROY ALL DATA on $disk. Continue?" && return 0
            return 1
            ;;
        *)
            if nds_skip_menu NDS_DISK_FORMAT_CONFIRM_SKIP \
                || nds_skip_menu NDS_INSTALL_CONFIRM_SKIP; then
                return 0
            fi
            nds_ask_user_to_proceed "Proceed with formatting $disk?" && return 0
            return 1
            ;;
    esac
}

# Description: Prompt for LUKS passphrase on /dev/tty; print passphrase to stdout.
nds_encryption_prompts_password() {
    local pw1="" pw2="" confirm
    while true; do
        printf 'Enter LUKS password: ' > /dev/tty
        read -rs pw1 < /dev/tty; printf '\n' > /dev/tty
        printf 'Confirm LUKS password: ' > /dev/tty
        read -rs pw2 < /dev/tty; printf '\n' > /dev/tty
        if [[ -z "$pw1" ]]; then
            printf 'Password cannot be empty — try again.\n' > /dev/tty; continue
        fi
        if [[ "$pw1" != "$pw2" ]]; then
            printf 'Passwords do not match — try again.\n' > /dev/tty; continue
        fi
        if [[ ${#pw1} -lt 12 ]]; then
            printf 'Password is short (%s chars) — consider a longer one.\n' "${#pw1}" > /dev/tty
            printf 'Use this password anyway? [y/N]: ' > /dev/tty
            read -r confirm < /dev/tty
            [[ "${confirm,,}" == "y" ]] || continue
        fi
        break
    done
    printf '%s' "$pw1"
}

# Description: Prompt for existing keyfile path on /dev/tty; print path to stdout.
nds_encryption_prompts_keyfile_path() {
    local src_path
    while true; do
        printf 'Enter path to existing keyfile on the live system: ' > /dev/tty
        read -r src_path < /dev/tty
        if [[ -n "$src_path" && -f "$src_path" ]]; then
            printf '%s' "$src_path"
            return 0
        fi
        printf 'File not found: %s — try again.\n' "$src_path" > /dev/tty
    done
}
