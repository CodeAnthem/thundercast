#!/usr/bin/env bash
# ==================================================================================================
# NDS - /dev/urandom helpers (standalone)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-08-16
# Description:   openssl-free random string generation for live ISO
# ==================================================================================================

# Description: Generate N random alphanumeric characters from /dev/urandom.
# Arguments:
# - count: <String> Number of characters
# Returns:
# - <String> random string on stdout
nds_install_urandom_chars() {
    nds_lib_urandom_chars "$@"
}
