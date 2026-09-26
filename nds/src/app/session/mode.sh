#!/usr/bin/env bash
# ==================================================================================================
# NDS - Run mode
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-09-26
# Description:   interactive or unattended. A terminal defaults to interactive.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_mode_resolve() {
    if [[ -n ${NDS_MODE:-} ]]; then
        case "$NDS_MODE" in
            interactive|unattended) ;;
            *)
                error "NDS_MODE: must be interactive or unattended"
                return 1
                ;;
        esac
    elif [[ -t 0 ]]; then
        NDS_MODE=interactive
    else
        NDS_MODE=unattended
    fi
    export NDS_MODE
}

nds_mode_is_unattended() {
    [[ ${NDS_MODE:-} == unattended ]]
}

nds_mode_is_interactive() {
    [[ ${NDS_MODE:-} == interactive ]]
}
