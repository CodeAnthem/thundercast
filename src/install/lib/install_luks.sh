#!/usr/bin/env bash
# ==================================================================================================
# NDS - LUKS formatting (standalone)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-07-28
# Description:   Format a partition as LUKS2 and create root filesystem
# ==================================================================================================

# Description: Format a partition as LUKS2, open it, and create ext4 on /dev/mapper/cryptroot.
# Arguments:
# - partition:     <String> Block partition to format
# - use_password:  <Bool> Unlock with password
# - use_key:       <Bool> Unlock with keyfile
# - secrets_dir:   <String> Directory containing luks_password.txt and/or luks_key.bin
# Returns:
# - <Bool> 0 on success
nds_install_luks_format_partition() {
    local partition="$1"
    local use_password="$2"
    local use_key="$3"
    local secrets_dir="$4"
    local passphrase="" keyfile_path=""

    if declare -f log &>/dev/null; then
        log "Formatting LUKS2 on $partition"
    fi
    wipefs -a "$partition" 2>/dev/null || true

    [[ "$use_password" == "true" ]] && passphrase=$(<"${secrets_dir}/luks_password.txt")
    [[ "$use_key" == "true" ]] && keyfile_path="${secrets_dir}/luks_key.bin"

    if [[ "$use_password" == "true" && "$use_key" == "true" ]]; then
        if declare -f log &>/dev/null; then
            log "Formatting with password (slot 0) + keyfile (slot 1)"
        fi
        printf '%s' "$passphrase" | cryptsetup luksFormat --type luks2 "$partition" - || return 1
        printf '%s' "$passphrase" | cryptsetup open "$partition" cryptroot - || return 1
        printf '%s' "$passphrase" | cryptsetup luksAddKey "$partition" "$keyfile_path" - || return 1
    elif [[ "$use_password" == "true" ]]; then
        if declare -f log &>/dev/null; then
            log "Formatting with password (slot 0)"
        fi
        printf '%s' "$passphrase" | cryptsetup luksFormat --type luks2 "$partition" - || return 1
        printf '%s' "$passphrase" | cryptsetup open "$partition" cryptroot - || return 1
    elif [[ "$use_key" == "true" ]]; then
        if declare -f log &>/dev/null; then
            log "Formatting with keyfile (slot 0)"
        fi
        cryptsetup luksFormat --type luks2 "$partition" "$keyfile_path" || return 1
        cryptsetup open "$partition" cryptroot "$keyfile_path" || return 1
    else
        if declare -f error &>/dev/null; then
            error "No unlock method configured — cannot format LUKS"
        fi
        return 1
    fi

    mkfs.ext4 -L nixos /dev/mapper/cryptroot || return 1
    return 0
}
