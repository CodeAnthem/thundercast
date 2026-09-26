#!/usr/bin/env bash
# ==================================================================================================
# NDS - Schema group encryption
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_validate_unlockShutdown() {
    local _nds_enc_value=$1
    [[ "$_nds_enc_value" =~ ^[0-9]+$ ]] || return 1
    [[ "$_nds_enc_value" -eq 0 ]] && return 0
    [[ "$_nds_enc_value" -ge 30 && "$_nds_enc_value" -le 3600 ]]
}

nds_check_encryption() {
    local -n _nds_enc_aa=$1
    local _nds_enc_n=0
    [[ ${_nds_enc_aa[ENCRYPTION]:-} == true ]] || return 0
    if [[ ${_nds_enc_aa[ENCRYPTION_PASSWORD]:-} != true && ${_nds_enc_aa[ENCRYPTION_KEY]:-} != true ]]; then
        error "ENCRYPTION_PASSWORD: at least one unlock method must be enabled"
        _nds_enc_n=$((_nds_enc_n + 1))
    fi
    if [[ ${_nds_enc_aa[ENCRYPTION_PASSWORD]:-} == true && ${_nds_enc_aa[ENCRYPTION_PASSWORD_AUTO]:-} == false && -z ${_nds_enc_aa[ENCRYPTION_PASSPHRASE_FILE]:-} ]]; then
        error "ENCRYPTION_PASSPHRASE_FILE: required"
        _nds_enc_n=$((_nds_enc_n + 1))
    fi
    if [[ ${_nds_enc_aa[ENCRYPTION_KEY]:-} == true && ${_nds_enc_aa[ENCRYPTION_KEY_AUTO]:-} == false && -z ${_nds_enc_aa[ENCRYPTION_KEY_FILE]:-} ]]; then
        error "ENCRYPTION_KEY_FILE: required"
        _nds_enc_n=$((_nds_enc_n + 1))
    fi
    if [[ ${_nds_enc_aa[ENCRYPTION_KEY]:-} == true && ${_nds_enc_aa[ENCRYPTION_PASSWORD]:-} != true ]]; then
        warn "ENCRYPTION_KEY: key-only mode cannot boot if the USB is lost"
    fi
    if [[ ${_nds_enc_aa[ENCRYPTION_REMOTE_UNLOCK]:-} == true && ${_nds_enc_aa[ENCRYPTION_REMOTE_NETWORK]:-} == static && -z ${_nds_enc_aa[NETWORK_IP]:-} ]]; then
        error "NETWORK_IP: static remote unlock needs an IP address"
        _nds_enc_n=$((_nds_enc_n + 1))
    fi
    if [[ ${_nds_enc_aa[ENCRYPTION_REMOTE_UNLOCK]:-} == true && ${_nds_enc_aa[ENCRYPTION_PASSWORD]:-} != true ]]; then
        warn "ENCRYPTION_REMOTE_UNLOCK: remote unlock needs a password slot"
    fi
    return "$_nds_enc_n"
}

nds_schema_group encryption "Encryption" --check nds_check_encryption
nds_schema_field encryption ENCRYPTION bool --default true --label 'Enable encryption'
nds_schema_field encryption ENCRYPTION_PASSWORD bool --default true --when 'ENCRYPTION=true' --label 'Use password'
nds_schema_field encryption ENCRYPTION_KEY bool --default false --when 'ENCRYPTION=true' --label 'Use key'
nds_schema_field encryption ENCRYPTION_REMOTE_UNLOCK bool --default false --when 'ENCRYPTION=true' \
    --label 'Remote unlock'
nds_schema_field encryption ENCRYPTION_PASSWORD_AUTO bool --default true \
    --when 'ENCRYPTION=true,ENCRYPTION_PASSWORD=true' --label 'Auto-generate password'
nds_schema_field encryption ENCRYPTION_PASSWORD_LENGTH int --default 64 --min 16 --max 128 \
    --when 'ENCRYPTION=true,ENCRYPTION_PASSWORD=true,ENCRYPTION_PASSWORD_AUTO=true' --label 'Password length'
nds_schema_field encryption ENCRYPTION_PASSPHRASE_FILE secret \
    --when 'ENCRYPTION=true,ENCRYPTION_PASSWORD=true' \
    --generate nds_generate_password \
    --generate-when 'ENCRYPTION_PASSWORD=true,ENCRYPTION_PASSWORD_AUTO=true' \
    --label 'Encryption passphrase file'
nds_schema_field encryption ENCRYPTION_KEY_AUTO bool --default true \
    --when 'ENCRYPTION=true,ENCRYPTION_KEY=true' --label 'Auto-generate key'
nds_schema_field encryption ENCRYPTION_KEY_LENGTH int --default 4096 --min 512 --max 8192 \
    --when 'ENCRYPTION=true,ENCRYPTION_KEY=true,ENCRYPTION_KEY_AUTO=true' --label 'Key length'
nds_schema_field encryption ENCRYPTION_KEY_FILE secret \
    --when 'ENCRYPTION=true,ENCRYPTION_KEY=true' \
    --generate nds_generate_bytes \
    --generate-when 'ENCRYPTION_KEY=true,ENCRYPTION_KEY_AUTO=true' \
    --label 'Encryption key file'
nds_schema_field encryption ENCRYPTION_KEY_BOOT_DEVICE string --required \
    --when 'ENCRYPTION=true,ENCRYPTION_KEY=true' --label 'USB device path'
nds_schema_field encryption ENCRYPTION_KEY_BOOT_FILE string \
    --when 'ENCRYPTION=true,ENCRYPTION_KEY=true' --label 'Key file on USB'
nds_schema_field encryption ENCRYPTION_REMOTE_SSH_KEY string --required \
    --when 'ENCRYPTION=true,ENCRYPTION_REMOTE_UNLOCK=true' --label 'Authorized SSH public key'
nds_schema_field encryption ENCRYPTION_REMOTE_NETWORK choice --default dhcp \
    --when 'ENCRYPTION=true,ENCRYPTION_REMOTE_UNLOCK=true' \
    --choices 'dhcp|static' --labels 'dhcp=DHCP|static=Static IP' --label 'Initrd network'
nds_schema_field encryption ENCRYPTION_REMOTE_PORT port --default 2222 \
    --when 'ENCRYPTION=true,ENCRYPTION_REMOTE_UNLOCK=true' --label 'Remote unlock SSH port'
nds_schema_field encryption ENCRYPTION_REMOTE_HINT bool --default true \
    --when 'ENCRYPTION=true,ENCRYPTION_REMOTE_UNLOCK=true' --label 'Show console hint'
nds_schema_field encryption ENCRYPTION_REMOTE_SHUTDOWN int --default 0 --min 0 --max 3600 \
    --when 'ENCRYPTION=true,ENCRYPTION_REMOTE_UNLOCK=true' --validate nds_validate_unlockShutdown \
    --label 'Auto power-off'
nds_schema_field encryption ENCRYPTION_REMOTE_HOSTKEY_FILE secret \
    --when 'ENCRYPTION=true,ENCRYPTION_REMOTE_UNLOCK=true' \
    --generate nds_generate_sshHostKey --generate-when 'ENCRYPTION_REMOTE_UNLOCK=true' \
    --label 'Initrd host key file'
