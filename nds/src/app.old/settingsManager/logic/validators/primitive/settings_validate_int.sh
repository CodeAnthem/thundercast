#!/usr/bin/env bash
# ==================================================================================================
# NDS - Validators: integer and port
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-08-04
# ==================================================================================================

validate_int() {
    local value="$1" min max
    min="${2:-${VALIDATOR_OPTIONS[min]:-}}"
    max="${3:-${VALIDATOR_OPTIONS[max]:-}}"
    [[ "$value" =~ ^-?[0-9]+$ ]] || return 1
    [[ -n "$min" && "$value" -lt "$min" ]] && return 2
    [[ -n "$max" && "$value" -gt "$max" ]] && return 2
    return 0
}

# Used by validator specs (type "port") and any VALIDATOR_OPTIONS-driven callers.
validate_port() {
    local value="$1" min max
    min="${VALIDATOR_OPTIONS[min]:-1}"
    max="${VALIDATOR_OPTIONS[max]:-65535}"
    [[ "$value" =~ ^[0-9]+$ ]] || return 1
    (( value >= min && value <= max )) || return 2
    return 0
}
