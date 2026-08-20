#!/usr/bin/env bash
# ==================================================================================================
# NDS - Encryption secret generation (logic)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-08-05
# Description:   LUKS password/keyfile secrets for backup + format (prompts in install/ui)
# ==================================================================================================

_nds_install_urandom_chars() {
    nds_install_urandom_chars "$@"
}

# Description: Generate or collect unlock secrets; save under runtime secrets dir.
# Interactive prompts live in install/ui (tty under nds_step_exec).
_nds_install_generate_encryption_secrets() {
    local use_password use_key password_auto password_length use_key_auto key_length
    local runtime_secrets

    nds_install_ctx_ensure
    use_password="$(nds_install_ctx_get ENCRYPTION_PASSWORD)"
    use_key="$(nds_install_ctx_get ENCRYPTION_KEY)"
    password_auto="$(nds_install_ctx_get ENCRYPTION_PASSWORD_AUTO)"
    password_length="$(nds_install_ctx_get ENCRYPTION_PASSWORD_LENGTH)"
    use_key_auto="$(nds_install_ctx_get ENCRYPTION_KEY_AUTO)"
    key_length="$(nds_install_ctx_get ENCRYPTION_KEY_LENGTH)"

    runtime_secrets="${NDS_RUNTIME_DIR:-/tmp/nds_runtime_$$}/secrets"
    mkdir -p "$runtime_secrets" || { error "Cannot create secrets dir"; return 1; }

    if [[ "$use_password" == "true" ]]; then
        local passphrase pw_file="$runtime_secrets/luks_password.txt"
        local given_file
        given_file="$(nds_cfg_get ENCRYPTION_PASSPHRASE_FILE 2>/dev/null || true)"
        if [[ -n "$given_file" && -f "$given_file" ]]; then
            passphrase="$(cat "$given_file")"
            [[ -n "$passphrase" ]] || { error "ENCRYPTION_PASSPHRASE_FILE is empty"; return 1; }
        elif [[ "$password_auto" == "true" ]]; then
            log "Generating password (/dev/urandom, $password_length hex chars)"
            passphrase=$(_nds_install_urandom_chars "$password_length")
            if [[ -z "$passphrase" ]]; then
                error "Password generation from /dev/urandom failed"
                return 1
            fi
        else
            passphrase="$(nds_encryption_prompts_password)"
        fi

        printf '%s' "$passphrase" > "$pw_file"
        chmod 600 "$pw_file"
        [[ -s "$pw_file" ]] || { error "Failed to write password file"; return 1; }
        if declare -f nds_cfg_set &>/dev/null; then
            nds_cfg_set ENCRYPTION_PASSPHRASE_FILE "$pw_file"
        fi
        nds_install_log "Generated LUKS password (saved to secrets/luks_password.txt)"
    fi

    if [[ "$use_key" == "true" ]]; then
        local keyfile_path="$runtime_secrets/luks_key.bin"
        if [[ "$use_key_auto" == "true" ]]; then
            log "Generating keyfile (/dev/urandom, $key_length bytes)"
            head -c "$key_length" /dev/urandom > "$keyfile_path" || { error "Keyfile generation failed"; return 1; }
            [[ -s "$keyfile_path" ]] || { error "Keyfile is empty"; return 1; }
        else
            local src_path
            src_path="$(nds_encryption_prompts_keyfile_path)"
            cp "$src_path" "$keyfile_path"
        fi
        chmod 600 "$keyfile_path"
        nds_install_log "Generated LUKS keyfile (saved to secrets/luks_key.bin)"
    fi

    return 0
}

# Description: Format partition as LUKS2 using pre-generated secrets.
_nds_install_format_luks() {
    local partition="$1"
    local use_password use_key runtime_secrets

    nds_install_ctx_ensure
    use_password="${NDS_CTX_ENCRYPTION_PASSWORD}"
    use_key="${NDS_CTX_ENCRYPTION_KEY}"
    runtime_secrets="${NDS_RUNTIME_DIR:-/tmp/nds_runtime_$$}/secrets"

    nds_install_luks_format_partition "$partition" "$use_password" "$use_key" "$runtime_secrets" || return 1
    nds_install_log "LUKS2 formatted on $partition; root fs created"
    return 0
}
