#!/usr/bin/env bash
# ==================================================================================================
# NDS - Encryption secret generation (logic)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-09-02
# Description:   Prompts in install/ui; write/format via utilities/disk
# ==================================================================================================

# Description: Generate or collect unlock secrets; save under runtime secrets dir.
# Interactive prompts live in install/ui (tty under nds_step_exec).
_nds_install_generate_encryption_secrets() {
    local use_password use_key password_auto password_length use_key_auto key_length
    local runtime_secrets given_file passphrase_tmp="" keyfile_src=""
    local -A _sec

    nds_requireUtility disk || return 1
    nds_install_ctx_ensure
    use_password="$(nds_install_ctx_get ENCRYPTION_PASSWORD)"
    use_key="$(nds_install_ctx_get ENCRYPTION_KEY)"
    password_auto="$(nds_install_ctx_get ENCRYPTION_PASSWORD_AUTO)"
    password_length="$(nds_install_ctx_get ENCRYPTION_PASSWORD_LENGTH)"
    use_key_auto="$(nds_install_ctx_get ENCRYPTION_KEY_AUTO)"
    key_length="$(nds_install_ctx_get ENCRYPTION_KEY_LENGTH)"

    runtime_secrets="${NDS_RUNTIME_DIR:-/tmp/nds_runtime_$$}/secrets"
    mkdir -p "$runtime_secrets" || { error "Cannot create secrets dir"; return 1; }

    given_file="$(nds_cfg_get ENCRYPTION_PASSPHRASE_FILE 2>/dev/null || true)"
    if [[ "$use_password" == "true" && "$password_auto" != "true" ]]; then
        if [[ -z "$given_file" || ! -f "$given_file" ]]; then
            passphrase_tmp="${runtime_secrets}/.prompt_passphrase"
            printf '%s' "$(nds_encryption_prompts_password)" >"$passphrase_tmp"
            chmod 600 "$passphrase_tmp"
            given_file="$passphrase_tmp"
        fi
    fi

    if [[ "$use_key" == "true" && "$use_key_auto" != "true" ]]; then
        keyfile_src="$(nds_encryption_prompts_keyfile_path)"
    fi

    _sec=(
        [secrets_dir]="$runtime_secrets"
        [use_password]="$use_password"
        [use_key]="$use_key"
        [password_auto]="$password_auto"
        [password_length]="$password_length"
        [key_auto]="$use_key_auto"
        [key_length]="$key_length"
        [passphrase_file]="${given_file:-}"
        [keyfile_src]="$keyfile_src"
    )
    disk_writeEncryptionSecrets _sec || return 1

    if [[ "$use_password" == "true" && -n "${_sec[passphrase_file]:-}" ]]; then
        if declare -f nds_cfg_set &>/dev/null; then
            nds_cfg_set ENCRYPTION_PASSPHRASE_FILE "${_sec[passphrase_file]}"
        fi
        nds_install_log "Generated LUKS password (saved to secrets/luks_password.txt)"
    fi
    if [[ "$use_key" == "true" ]]; then
        nds_install_log "Generated LUKS keyfile (saved to secrets/luks_key.bin)"
    fi
    [[ -n "$passphrase_tmp" && -f "$passphrase_tmp" ]] && rm -f "$passphrase_tmp"
    return 0
}

# Description: Format partition as LUKS2 using pre-generated secrets.
_nds_install_format_luks() {
    local partition="$1"
    local use_password use_key runtime_secrets

    nds_requireUtility disk || return 1
    nds_install_ctx_ensure
    use_password="${NDS_CTX_ENCRYPTION_PASSWORD}"
    use_key="${NDS_CTX_ENCRYPTION_KEY}"
    runtime_secrets="${NDS_RUNTIME_DIR:-/tmp/nds_runtime_$$}/secrets"

    disk_luksFormat "$partition" "$use_password" "$use_key" "$runtime_secrets" || return 1
    nds_install_log "LUKS2 formatted on $partition; root fs created"
    return 0
}
