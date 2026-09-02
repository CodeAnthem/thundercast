#!/usr/bin/env bash
# ==================================================================================================
# NDS - Validators: toggle / boolean
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# ==================================================================================================

validate_toggle() {
    [[ "${1,,}" =~ ^(true|false|enabled|disabled|yes|no|y|n|1|0)$ ]]
}

_nds_settings_error_toggle() {
    echo "Enter yes, no, true, false, enabled, or disabled"
}

# Description: Normalize user input to true|false.
# Returns:
# - <String> true or false (stdout)
validate_toggle_normalize() {
    case "${1,,}" in
        true|enabled|yes|y|1) echo "true" ;;
        false|disabled|no|n|0) echo "false" ;;
        *) echo "$1" ;;
    esac
}
