#!/usr/bin/env bash
# ==================================================================================================
# NDS - Settings manager country validation
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-07-28
# Description:   Validate country codes against settings-manager reference data
# ==================================================================================================

# Description: Country validator uses settings-manager country reference data.
# Arguments:
# - value: <String> Two-letter country code
# Returns:
# - <Int> 0 valid, 1 malformed, 2 unknown country code
validate_country() {
    local value="$1"
    [[ "$value" =~ ^[A-Za-z]{2}$ ]] || return 1
    nds_country_defaults "${value,,}" &>/dev/null || return 2
    return 0
}
