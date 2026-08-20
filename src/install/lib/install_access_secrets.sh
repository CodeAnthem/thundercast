#!/usr/bin/env bash
# ==================================================================================================
# NDS - Admin access secrets (standalone)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-07-28
# Description:   Generate admin password file (argument-only)
# ==================================================================================================

# Description: Resolve admin password and write admin_password.txt under secrets_dir.
# Arguments:
# - auto_generate:  <Bool> Generate from /dev/urandom when true
# - length:         <String> Character count when auto-generating
# - manual:         <String> User-supplied password when auto_generate is false
# - secrets_dir:    <String> Runtime secrets directory
# Returns:
# - <Bool> 0 on success
nds_install_write_admin_password() {
    local auto_generate="$1"
    local length="$2"
    local manual="$3"
    local secrets_dir="$4"
    local pw_file pw

    mkdir -p "$secrets_dir" || {
        if declare -f error &>/dev/null; then
            error "Cannot create secrets dir"
        fi
        return 1
    }
    pw_file="${secrets_dir}/admin_password.txt"

    if [[ "$auto_generate" == "true" ]]; then
        if declare -f log &>/dev/null; then
            log "Generating admin password (/dev/urandom, ${length} hex chars)"
        fi
        pw=$(nds_install_urandom_chars "$length")
        if [[ -z "$pw" ]]; then
            if declare -f error &>/dev/null; then
                error "Admin password generation from /dev/urandom failed"
            fi
            return 1
        fi
    else
        pw="$manual"
        if [[ -z "$pw" ]]; then
            if declare -f error &>/dev/null; then
                error "Auto-generate is off but no admin password was set"
            fi
            return 1
        fi
    fi

    printf '%s' "$pw" >"$pw_file"
    chmod 600 "$pw_file"
    [[ -s "$pw_file" ]] || {
        if declare -f error &>/dev/null; then
            error "Failed to write admin password file"
        fi
        return 1
    }
    return 0
}
