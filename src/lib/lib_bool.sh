#!/usr/bin/env bash
# ==================================================================================================
# NDS - Shared boolean helpers
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-16 | Modified: 2026-08-16
# Description:   Env/toggle truthiness (no feature policy)
# ==================================================================================================

# Description: True when a value is boolean true (true/1, case-insensitive).
# Arguments:
# - value: <String> Candidate
# Returns:
# - <Bool> 0 when true
nds_lib_env_is_true() {
    local value="${1:-}"
    [[ "${value,,}" == "true" || "$value" == "1" ]]
}
