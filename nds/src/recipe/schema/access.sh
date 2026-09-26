#!/usr/bin/env bash
# ==================================================================================================
# NDS - Schema group access
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_check_access() {
    local -n _nds_acc_aa=$1
    local _nds_acc_n=0
    if [[ ${_nds_acc_aa[ACCESS_ADMIN_PASSWORD_AUTO]:-} == false && -z ${_nds_acc_aa[ACCESS_ADMIN_PASSWORD_FILE]:-} ]]; then
        error "ACCESS_ADMIN_PASSWORD_FILE: required"
        _nds_acc_n=$((_nds_acc_n + 1))
    fi
    if [[ ${_nds_acc_aa[ACCESS_SSH_ENABLE]:-} == true && ${_nds_acc_aa[ACCESS_SSH_PASSWORD_AUTH]:-} == false && -z ${_nds_acc_aa[ACCESS_ADMIN_SSH_KEY]:-} ]]; then
        error "ACCESS_ADMIN_SSH_KEY: required"
        _nds_acc_n=$((_nds_acc_n + 1))
    fi
    return "$_nds_acc_n"
}

nds_schema_group access "Access" --check nds_check_access
nds_schema_field access ACCESS_ADMIN_USER username --required --default admin --label 'Admin username'
nds_schema_field access ACCESS_ADMIN_PASSWORD_AUTO bool --default true --label 'Auto-generate admin password'
nds_schema_field access ACCESS_ADMIN_PASSWORD_LENGTH int --default 32 --min 16 --max 128 \
    --when 'ACCESS_ADMIN_PASSWORD_AUTO=true' --label 'Admin password length'
nds_schema_field access ACCESS_ADMIN_PASSWORD_FILE secret \
    --generate nds_generate_password --generate-when 'ACCESS_ADMIN_PASSWORD_AUTO=true' \
    --label 'Admin password file'
nds_schema_field access ACCESS_ADMIN_SSH_KEY string --label 'Admin SSH public key'
nds_schema_field access ACCESS_SUDO_PASSWORD_REQUIRED bool --default true --label 'Sudo requires password'
nds_schema_field access ACCESS_SSH_ENABLE bool --default true --label 'Enable SSH'
nds_schema_field access ACCESS_SSH_PORT port --default 22 --when 'ACCESS_SSH_ENABLE=true' --label 'SSH port'
nds_schema_field access ACCESS_SSH_PASSWORD_AUTH bool --default true --when 'ACCESS_SSH_ENABLE=true' \
    --label 'Allow SSH password login'
