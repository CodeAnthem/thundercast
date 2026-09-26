#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install an existing machine age key onto a mount
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-03 | Modified: 2026-09-26
# Description:   Copy a key file and write the public key plus an enroll note.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_sops_enroll_note() {
    local dest=$1 hostname=$2 pubkey=$3
    cat > "$dest" << EOF
# sops enrollment for ${hostname}

Machine age public key:

    ${pubkey}

Add the public key to .sops.yaml, re-encrypt the host secrets, and commit.
The private key is at /etc/sops/age/keys.txt on the machine.
EOF
}

sops_installKey() {
    local _sops_key=$1 _sops_mnt=$2 _sops_secrets=$3 _sops_host=$4
    local _sops_pub
    [[ -f "$_sops_key" ]] || {
        error "SOPS_AGE_KEY_FILE: not found"
        return 1
    }
    mkdir -p "${_sops_mnt}/etc/sops/age" "$_sops_secrets" || return 1
    cp "$_sops_key" "${_sops_mnt}/etc/sops/age/keys.txt" || return 1
    chmod 600 "${_sops_mnt}/etc/sops/age/keys.txt" || return 1
    _sops_pub=$(awk -F': ' '/^# public key: / { print $2; exit }' "$_sops_key")
    [[ -n "$_sops_pub" ]] || {
        error "SOPS_AGE_KEY_FILE: public key missing"
        return 1
    }
    printf '%s\n' "$_sops_pub" > "${_sops_secrets}/age_pubkey.txt"
    _sops_enroll_note "${_sops_secrets}/sops_enroll.md" "$_sops_host" "$_sops_pub"
}
