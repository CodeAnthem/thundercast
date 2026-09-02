#!/usr/bin/env bash
# ==================================================================================================
# NDS - Shared boolean helpers
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-16 | Modified: 2026-08-31
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

# Description: Parse a boolean string. Case-insensitive.
# True:  true t yes y on enable enabled 1
# False: false f no n off disable disabled 0
# Arguments:
# - value: <String> Candidate
# Returns:
# - <Bool> 0 true, 1 false, 2 invalid
nds_lib_bool_parse() {
    case "${1,,}" in
        true|t|yes|y|on|enable|enabled|1)
            echo "true"
            return 0
            ;;
        false|f|no|n|off|disable|disabled|0)
            echo "false"
            return 0
            ;;
        *)
            printf 'nds_lib_bool_parse: invalid boolean value: %q\n' "$1" >&2
            return 1
            ;;
    esac
}
