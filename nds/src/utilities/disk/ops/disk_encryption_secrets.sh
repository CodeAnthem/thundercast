#!/usr/bin/env bash
# ==================================================================================================
# disk utility - write LUKS secrets (no prompts)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# Description:   Shot caller / wizard supplies passphrase_file or asks first.
# ==================================================================================================

# Description: Write LUKS password/keyfile into secrets_dir.
# Arguments:
# - opts: <Nameref> secrets_dir, use_password, use_key, password_auto, password_length,
#         key_auto, key_length, passphrase_file, keyfile_src
disk_writeEncryptionSecrets() {
    local -n _dwe=$1
    local secrets_dir="${_dwe[secrets_dir]:-}"
    local use_password="${_dwe[use_password]:-false}"
    local use_key="${_dwe[use_key]:-false}"
    local password_auto="${_dwe[password_auto]:-true}"
    local password_length="${_dwe[password_length]:-32}"
    local key_auto="${_dwe[key_auto]:-true}"
    local key_length="${_dwe[key_length]:-64}"
    local passphrase_file="${_dwe[passphrase_file]:-}"
    local keyfile_src="${_dwe[keyfile_src]:-}"
    local passphrase pw_file keyfile_path

    [[ -n "$secrets_dir" ]] || { err "secrets_dir required"; return 1; }
    mkdir -p "$secrets_dir" || { err "Cannot create secrets dir"; return 1; }

    if [[ "$use_password" == "true" ]]; then
        pw_file="${secrets_dir}/luks_password.txt"
        if [[ -n "$passphrase_file" && -f "$passphrase_file" ]]; then
            passphrase=$(<"$passphrase_file")
            [[ -n "$passphrase" ]] || { err "passphrase_file is empty"; return 1; }
        elif [[ "$password_auto" == "true" ]]; then
            log "Generating password (/dev/urandom, $password_length chars)"
            passphrase=${ disk_urandomChars "$password_length"; }
            [[ -n "$passphrase" ]] || { err "Password generation failed"; return 1; }
        else
            err "use_password needs passphrase_file or password_auto=true"
            return 1
        fi
        printf '%s' "$passphrase" >"$pw_file"
        chmod 600 "$pw_file"
        [[ -s "$pw_file" ]] || { err "Failed to write password file"; return 1; }
        _dwe[passphrase_file]="$pw_file"
    fi

    if [[ "$use_key" == "true" ]]; then
        keyfile_path="${secrets_dir}/luks_key.bin"
        if [[ "$key_auto" == "true" ]]; then
            log "Generating keyfile (/dev/urandom, $key_length bytes)"
            head -c "$key_length" /dev/urandom >"$keyfile_path" || { err "Keyfile generation failed"; return 1; }
            [[ -s "$keyfile_path" ]] || { err "Keyfile is empty"; return 1; }
        else
            [[ -n "$keyfile_src" && -f "$keyfile_src" ]] || {
                err "use_key with key_auto=false requires keyfile_src"
                return 1
            }
            cp "$keyfile_src" "$keyfile_path"
        fi
        chmod 600 "$keyfile_path"
    fi
    return 0
}
