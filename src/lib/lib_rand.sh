#!/usr/bin/env bash
# ==================================================================================================
# NDS - Shared /dev/urandom helpers
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-16 | Modified: 2026-08-16
# Description:   openssl-free random strings (no feature policy)
# ==================================================================================================

# Description: Generate N random alphanumeric characters from /dev/urandom.
# Arguments:
# - count: <String> Number of characters
# Returns:
# - <String> random string on stdout
nds_lib_urandom_chars() {
    local n="$1"
    local raw
    raw=$(LC_ALL=C tr -dc 'A-Za-z0-9' < <(head -c "$(( n * 8 + 128 ))" /dev/urandom))
    printf '%s' "${raw:0:n}"
}
