#!/usr/bin/env bash
# ==================================================================================================
# NDS - Shared key-text helpers
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-16 | Modified: 2026-08-16
# Description:   PEM / OpenSSH private-key markers (no ssh-agent, no paths)
# ==================================================================================================

# Description: True when text looks like an OpenSSH/PEM private key.
# Arguments:
# - body: <String> Key material
# Returns:
# - <Bool> 0 when BEGIN/END PRIVATE KEY markers are present
nds_lib_key_bodyLooksValid() {
    local body="$1"
    [[ "$body" == *"BEGIN"* && "$body" == *"PRIVATE KEY"* && "$body" == *"END"* ]]
}
