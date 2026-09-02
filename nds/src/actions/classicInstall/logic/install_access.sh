#!/usr/bin/env bash
# ==================================================================================================
# NDS - Access secrets (admin password + runtime secret listing)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-08-04
# ==================================================================================================

# Description: Resolve the admin password and write runtime secrets (NDS adapter).
# Run before writing configuration.nix.
_nds_install_generate_access_secrets() {
    local runtime_secrets

    nds_install_ctx_ensure
    runtime_secrets="${NDS_RUNTIME_DIR:-/tmp/nds_runtime_$$}/secrets"

    nds_install_write_admin_password \
        "${NDS_CTX_ADMIN_PASSWORD_AUTO}" \
        "${NDS_CTX_ADMIN_PASSWORD_LENGTH}" \
        "${NDS_CTX_ADMIN_PASSWORD}" \
        "$runtime_secrets" || return 1

    nds_install_log "Generated admin password (saved to secrets/admin_password.txt)"
    return 0
}

# Description: List secret files produced during this install run.
# Returns:
# - <String> One absolute path per line
nds_secrets_list_runtime() {
    local item

    if [[ -d "${NDS_RUNTIME_DIR:-}/secrets" ]]; then
        for item in "${NDS_RUNTIME_DIR}/secrets"/*; do
            [[ -f "$item" ]] && echo "$item"
        done
    fi
}
