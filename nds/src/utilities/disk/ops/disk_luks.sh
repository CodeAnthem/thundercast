#!/usr/bin/env bash
# ==================================================================================================
# disk utility - LUKS format
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

# Description: Format a partition as LUKS2 using the given secret files.
# Arguments:
# - partition:       <String> Block partition
# - passphrase_file: <String> Passphrase file, or empty
# - keyfile:         <String> Key file, or empty
disk_luksFormat() {
    local _disk_part=$1 _disk_pass=${2:-} _disk_key=${3:-}
    [[ -n "$_disk_pass" || -n "$_disk_key" ]] || {
        err "No unlock material — cannot format LUKS"
        return 1
    }
    debug "Formatting LUKS2 on ${_disk_part}"
    wipefs -a "$_disk_part" 2>/dev/null || true
    if [[ -n "$_disk_pass" && -n "$_disk_key" ]]; then
        cryptsetup luksFormat --type luks2 "$_disk_part" --key-file "$_disk_pass" || return 1
        cryptsetup open "$_disk_part" cryptroot --key-file "$_disk_pass" || return 1
        cryptsetup luksAddKey "$_disk_part" "$_disk_key" --key-file "$_disk_pass" || return 1
    elif [[ -n "$_disk_pass" ]]; then
        cryptsetup luksFormat --type luks2 "$_disk_part" --key-file "$_disk_pass" || return 1
        cryptsetup open "$_disk_part" cryptroot --key-file "$_disk_pass" || return 1
    else
        cryptsetup luksFormat --type luks2 "$_disk_part" "$_disk_key" || return 1
        cryptsetup open "$_disk_part" cryptroot --key-file "$_disk_key" || return 1
    fi
    mkfs.ext4 -L nixos /dev/mapper/cryptroot || return 1
}
