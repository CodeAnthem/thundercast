#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-27 | Modified: 2026-07-01
# Description:   Initrd SSH host keys for remote LUKS unlock (install-time only)
# Feature:       Generates ed25519 host keys at /etc/secrets/initrd/ on the target,
#                embedded into the initrd via boot.initrd.secretPaths. Also staged
#                into the runtime secrets bundle so the user can back them up.
# ==================================================================================================

# Description: Generate the initrd SSH host key used by the remote-unlock SSH
# server. The key is written to /mnt/etc/secrets/initrd/ on the target so the
# NixOS config can embed it into the initrd via boot.initrd.secretPaths, and
# copied to the runtime secrets bundle for the backup zip.
# Usage: _nds_install_setup_initrd_ssh_keys
_nds_install_setup_initrd_ssh_keys() {
    local target_dir="/mnt/etc/secrets/initrd"
    local key_path="${target_dir}/ssh_host_ed25519_key"
    local runtime_secrets="${NDS_RUNTIME_DIR:-/tmp/nds_runtime_$$}/secrets"

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

    # Stage into the backup bundle so the user can recover the host identity.
    mkdir -p "$runtime_secrets"
    cp "$key_path" "${runtime_secrets}/initrd_ssh_host_ed25519_key" || return 1
    cp "${key_path}.pub" "${runtime_secrets}/initrd_ssh_host_ed25519_key.pub" || return 1
    chmod 600 "${runtime_secrets}/initrd_ssh_host_ed25519_key"

    success "Initrd SSH host key written to ${target_dir} and staged for backup"
    nds_install_log "Generated initrd SSH host key (ed25519) for remote unlock"
    return 0
}
