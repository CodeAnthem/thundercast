#!/usr/bin/env bash
# ==================================================================================================
# NDS - Validators: secret files (paths only — never the secret bytes)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-20 | Modified: 2026-08-20
# ==================================================================================================

# Description: True when path is an absolute, readable, non-empty file (mode 600 preferred).
# Arguments:
# - path: <String> Absolute path to a secret file
# Returns:
# - <Bool> 0 when the file can be used as a secret source
validate_secret_file() {
    local path="$1"
    local mode

    [[ -n "$path" ]] || return 1
    [[ "$path" == /* ]] || return 1
    [[ -f "$path" ]] || return 1
    [[ -r "$path" ]] || return 1
    [[ -s "$path" ]] || return 1

    mode="$(stat -c '%a' "$path" 2>/dev/null || stat -f '%OLp' "$path" 2>/dev/null || echo "")"
    if [[ -n "$mode" && "$mode" != "600" && "$mode" != "400" && "$mode" != "0600" && "$mode" != "0400" ]]; then
        if declare -f warn &>/dev/null; then
            warn "Secret file ${path} mode is ${mode} (expected 600)"
        fi
    fi
    return 0
}
