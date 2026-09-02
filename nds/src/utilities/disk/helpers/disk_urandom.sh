#!/usr/bin/env bash
# ==================================================================================================
# disk utility - random material for LUKS secrets
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# ==================================================================================================

# Description: Random alphanumeric string (uses nds_lib when present).
# Arguments:
# - count: <String> Length
# Returns:
# - <String> on stdout
disk_urandomChars() {
    if declare -f nds_lib_urandom_chars &>/dev/null; then
        nds_lib_urandom_chars "$@"
        return $?
    fi
    local n="$1" raw
    raw=$(LC_ALL=C tr -dc 'A-Za-z0-9' < <(head -c "$(( n * 8 + 128 ))" /dev/urandom))
    printf '%s' "${raw:0:n}"
}
