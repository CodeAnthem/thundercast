#!/usr/bin/env bash
# ==================================================================================================
# disk utility - LUKS format
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-09-02
# ==================================================================================================

# Description: Format partition as LUKS2, open cryptroot, mkfs.ext4 -L nixos.
# Arguments:
# - partition:    <String> Block partition
# - use_password: <Bool>
# - use_key:      <Bool>
# - secrets_dir:  <String> Dir with luks_password.txt and/or luks_key.bin
disk_luksFormat() {
    local partition="$1"
    local use_password="$2"
    local use_key="$3"
    local secrets_dir="$4"
    local passphrase="" keyfile_path=""

    log "Formatting LUKS2 on $partition"
    wipefs -a "$partition" 2>/dev/null || true

    [[ "$use_password" == "true" ]] && passphrase=$(<"${secrets_dir}/luks_password.txt")
    [[ "$use_key" == "true" ]] && keyfile_path="${secrets_dir}/luks_key.bin"

    if [[ "$use_password" == "true" && "$use_key" == "true" ]]; then
        log "Formatting with password (slot 0) + keyfile (slot 1)"
        printf '%s' "$passphrase" | cryptsetup luksFormat --type luks2 "$partition" - || return 1
        printf '%s' "$passphrase" | cryptsetup open "$partition" cryptroot - || return 1
        printf '%s' "$passphrase" | cryptsetup luksAddKey "$partition" "$keyfile_path" - || return 1
    elif [[ "$use_password" == "true" ]]; then
        log "Formatting with password (slot 0)"
        printf '%s' "$passphrase" | cryptsetup luksFormat --type luks2 "$partition" - || return 1
        printf '%s' "$passphrase" | cryptsetup open "$partition" cryptroot - || return 1
    elif [[ "$use_key" == "true" ]]; then
        log "Formatting with keyfile (slot 0)"
        cryptsetup luksFormat --type luks2 "$partition" "$keyfile_path" || return 1
        cryptsetup open "$partition" cryptroot "$keyfile_path" || return 1
    else
        err "No unlock method configured — cannot format LUKS"
        return 1
    fi

    mkfs.ext4 -L nixos /dev/mapper/cryptroot || return 1
    return 0
}
