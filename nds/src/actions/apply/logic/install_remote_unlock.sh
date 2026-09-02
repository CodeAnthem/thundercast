#!/usr/bin/env bash
# ==================================================================================================
# NDS - Initrd SSH keys for remote LUKS unlock (shot caller → disk utility)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-27 | Modified: 2026-09-02
# ==================================================================================================

# Description: Generate initrd SSH host key on /mnt and stage into runtime secrets.
_nds_install_setup_initrd_ssh_keys() {
    local runtime_secrets="${NDS_RUNTIME_DIR:-/tmp/nds_runtime_$$}/secrets"

    nds_requireUtility disk || return 1
    disk_setupInitrdSshKeys /mnt "$runtime_secrets" || return 1
    success "Initrd SSH host key written to /mnt/etc/secrets/initrd and staged for backup"
    nds_install_log "Generated initrd SSH host key (ed25519) for remote unlock"
    return 0
}
