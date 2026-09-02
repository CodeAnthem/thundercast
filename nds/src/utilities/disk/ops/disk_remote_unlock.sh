#!/usr/bin/env bash
# ==================================================================================================
# disk utility - initrd SSH host key for remote LUKS unlock
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# ==================================================================================================

# Description: Generate initrd SSH host key on target and stage into secrets_dir.
# Arguments:
# - mount_root:  <String> Target root (e.g. /mnt)
# - secrets_dir: <String|optional> Runtime secrets dir for backup staging
disk_setupInitrdSshKeys() {
    local mount_root="${1:-/mnt}"
    local secrets_dir="${2:-}"
    local target_dir="${mount_root}/etc/secrets/initrd"
    local key_path="${target_dir}/ssh_host_ed25519_key"

    log "Generating initrd SSH host key for remote unlock"
    mkdir -p "$target_dir"
    chmod 700 "$target_dir"

    if [[ -f "$key_path" ]]; then
        warn "Initrd SSH host key already exists — skipping generation"
    else
        ssh-keygen -t ed25519 -f "$key_path" -N "" -C "initrd-remote-unlock" || return 1
        chmod 600 "$key_path"
        chmod 644 "${key_path}.pub"
    fi

    if [[ -n "$secrets_dir" ]]; then
        mkdir -p "$secrets_dir"
        cp "$key_path" "${secrets_dir}/initrd_ssh_host_ed25519_key" || return 1
        cp "${key_path}.pub" "${secrets_dir}/initrd_ssh_host_ed25519_key.pub" || return 1
        chmod 600 "${secrets_dir}/initrd_ssh_host_ed25519_key"
    fi
    return 0
}
