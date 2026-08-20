#!/usr/bin/env bash
# ==================================================================================================
# NDS - Validators: hostname
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# ==================================================================================================

validate_hostname() {
    local hostname="$1"
    local hostname_regex='^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$'
    [[ ${#hostname} -ge 2 ]] || return 1
    [[ "$hostname" =~ $hostname_regex ]]
}

_nds_settings_error_hostname() {
    echo "Invalid hostname (2-63 chars, lowercase alphanumeric, hyphens allowed in middle)"
}
