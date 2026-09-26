#!/usr/bin/env bash
# ==================================================================================================
# disk utility - copy an initrd SSH host key onto the target
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

# Description: Copy a cook-side initrd host key onto the mount.
# Arguments:
# - mount_root:  <String> Target root
# - hostkey_file: <String> Existing private key
disk_setupInitrdSshKeys() {
    local _disk_mnt=$1 _disk_key=$2
    local _disk_dir="${_disk_mnt}/etc/secrets/initrd"
    [[ -f "$_disk_key" ]] || return 1
    mkdir -p "$_disk_dir" || return 1
    chmod 700 "$_disk_dir" || return 1
    cp "$_disk_key" "${_disk_dir}/ssh_host_ed25519_key" || return 1
    chmod 600 "${_disk_dir}/ssh_host_ed25519_key" || return 1
    if [[ -f "${_disk_key}.pub" ]]; then
        cp "${_disk_key}.pub" "${_disk_dir}/ssh_host_ed25519_key.pub" || return 1
        chmod 644 "${_disk_dir}/ssh_host_ed25519_key.pub" || return 1
    fi
}
