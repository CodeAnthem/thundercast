#!/usr/bin/env bash
# ==================================================================================================
# nixcfg - admin password secret file (consumed by the access block)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-09-03
# ==================================================================================================

# Description: Resolve the admin password and write <secrets_dir>/admin_password.txt.
# Arguments:
# - auto_generate: <String> true → random from /dev/urandom
# - length:        <String> Character count when auto-generating
# - manual:        <String> User-supplied password when not auto-generating
# - secrets_dir:   <String> Runtime secrets directory
# Returns:
# - <Bool> 0 on success
nds_nixcfg_write_admin_password() {
    local auto_generate="$1"
    local length="$2"
    local manual="$3"
    local secrets_dir="$4"
    local pw_file pw

    mkdir -p "$secrets_dir" || { error "Cannot create secrets dir"; return 1; }
    pw_file="${secrets_dir}/admin_password.txt"

    if [[ "$auto_generate" == "true" ]]; then
        pw=${ nds_lib_urandom_chars "$length"; }
        [[ -n "$pw" ]] || { error "Admin password generation from /dev/urandom failed"; return 1; }
    else
        pw="$manual"
        [[ -n "$pw" ]] || { error "Auto-generate is off but no admin password was set"; return 1; }
    fi

    printf '%s' "$pw" >"$pw_file"
    chmod 600 "$pw_file"
    [[ -s "$pw_file" ]] || { error "Failed to write admin password file"; return 1; }
    return 0
}
