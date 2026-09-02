#!/usr/bin/env bash
# ==================================================================================================
# NDS - Validators: choice
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# ==================================================================================================

declare -gA VALIDATOR_OPTIONS=()

validate_choice() {
    local value="$1" options="${2:-${VALIDATOR_OPTIONS[options]:-}}"
    [[ -n "$options" ]] || return 3
    local choice
    IFS='|' read -ra choices <<< "$options"
    for choice in "${choices[@]}"; do
        [[ "$value" == "$choice" ]] && return 0
    done
    return 1
}
