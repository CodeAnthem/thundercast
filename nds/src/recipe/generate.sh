#!/usr/bin/env bash
# ==================================================================================================
# NDS - Recipe secret generators
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Write secret files at materialize. Never run at birth.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_nds_generate_passwordLength() {
    local -n _nds_gen_aa=$1
    local _nds_gen_stem=${2%_FILE} _nds_gen_key
    if [[ "$_nds_gen_stem" == *_PASSPHRASE ]]; then
        _nds_gen_key=${_nds_gen_stem%_PASSPHRASE}_PASSWORD_LENGTH
    elif [[ "$_nds_gen_stem" == *_PASSWORD ]]; then
        _nds_gen_key=${_nds_gen_stem}_LENGTH
    else
        _nds_gen_key=${_nds_gen_stem}_PASSWORD_LENGTH
    fi
    printf '%s\n' "${_nds_gen_aa[$_nds_gen_key]:-32}"
}

_nds_generate_keyLength() {
    local -n _nds_gen_aa=$1
    local _nds_gen_stem=${2%_FILE}
    printf '%s\n' "${_nds_gen_aa[${_nds_gen_stem}_LENGTH]:-4096}"
}

nds_generate_password() {
    local _nds_gen_key=$2 _nds_gen_dest=$3 _nds_gen_len _nds_gen_raw
    _nds_gen_len=${ _nds_generate_passwordLength "$1" "$_nds_gen_key"; }
    [[ "$_nds_gen_len" =~ ^[0-9]+$ && "$_nds_gen_len" -gt 0 ]] || return 1
    _nds_gen_raw=$(LC_ALL=C tr -dc 'A-Za-z0-9' < <(head -c "$((_nds_gen_len * 8 + 128))" /dev/urandom))
    printf '%s' "${_nds_gen_raw:0:_nds_gen_len}" > "$_nds_gen_dest" || return 1
    chmod 600 "$_nds_gen_dest"
}

nds_generate_bytes() {
    local _nds_gen_dest=$3 _nds_gen_len
    _nds_gen_len=${ _nds_generate_keyLength "$1" "$2"; }
    [[ "$_nds_gen_len" =~ ^[0-9]+$ && "$_nds_gen_len" -gt 0 ]] || return 1
    head -c "$_nds_gen_len" /dev/urandom > "$_nds_gen_dest" || return 1
    chmod 600 "$_nds_gen_dest"
}

nds_generate_sshHostKey() {
    local _nds_gen_dest=$3
    rm -f "$_nds_gen_dest" "${_nds_gen_dest}.pub"
    ssh-keygen -t ed25519 -f "$_nds_gen_dest" -N "" -q || return 1
    chmod 600 "$_nds_gen_dest"
}

nds_generate_ageKey() {
    local _nds_gen_dest=$3
    command -v age-keygen >/dev/null 2>&1 || { error "age: tool not loaded"; return 1; }
    age-keygen -o "$_nds_gen_dest" >/dev/null || return 1
    chmod 600 "$_nds_gen_dest"
}
