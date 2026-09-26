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

To grant this machine access to its secrets:

1. Add the public key to .sops.yaml under the relevant creation_rules
   (host-specific: secrets/hosts/${hostname}/*.yaml; shared: secrets/*.yaml).
2. Re-encrypt affected secrets so the new recipient can decrypt them:

    sops updatekeys secrets/hosts/${hostname}/*.yaml

3. Commit .sops.yaml and the updated secrets, then deploy.

The matching private key is installed on the machine at
/etc/sops/age/keys.txt and is backed up in this bundle as
secrets/age.key — keep it safe and offline.
EOF
}

sops_writeLeafPub() {
    local _sops_name=$1 _sops_leaf=$2
    local -n _sops_R=$1
    local _sops_host=${_sops_R[FLAKE_HOST]:-} _sops_key=${_sops_R[SOPS_AGE_KEY_FILE]:-}
    local _sops_pub _sops_dest
    [[ -n "$_sops_leaf" && -n "$_sops_host" ]] || return 0
    if [[ -z "$_sops_key" && ${_sops_R[SOPS_AGE_REUSE]:-generate} == generate ]]; then
        _sops_key="${ nds_session_dir secrets; }/SOPS_AGE_KEY"
        nds_generate_ageKey "$_sops_name" SOPS_AGE_KEY_FILE "$_sops_key" || return 1
        nds_recipe_set "$_sops_name" SOPS_AGE_KEY_FILE "$_sops_key" || return 1
    fi
    [[ -f "$_sops_key" ]] || return 0
    _sops_pub=$(awk -F': ' '/^# public key: / { print $2; exit }' "$_sops_key")
    [[ -n "$_sops_pub" ]] || return 0
    _sops_dest="${_sops_leaf}/.toolkit/machines/${_sops_host}/keys/age.pub"
    mkdir -p "${_sops_dest%/*}" || return 1
    printf '%s\n' "$_sops_pub" > "$_sops_dest"
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
    cp "$_sops_key" "${_sops_secrets}/age.key" || return 1
    chmod 600 "${_sops_secrets}/age.key" || return 1
    chmod 600 "${_sops_mnt}/etc/sops/age/keys.txt" || return 1
    _sops_pub=$(awk -F': ' '/^# public key: / { print $2; exit }' "$_sops_key")
    [[ -n "$_sops_pub" ]] || {
        error "SOPS_AGE_KEY_FILE: public key missing"
        return 1
    }
    printf '%s\n' "$_sops_pub" > "${_sops_secrets}/age_pubkey.txt"
    _sops_enroll_note "${_sops_secrets}/sops_enroll.md" "$_sops_host" "$_sops_pub"
}
