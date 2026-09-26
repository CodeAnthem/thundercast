#!/usr/bin/env bash
# ==================================================================================================
# NDS - Session exit hooks
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-23 | Modified: 2026-09-24
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_nds_session_publish() {
    declare -f nds_session_logs_publish >/dev/null || return 0
    nds_session_logs_publish || return 1
}

_nds_session_onExitError() {
    logger_compose "NDS" session || return 1
    warn "NDS failed (${1:-?}). Installer output stays in the nixos scope."
    declare -f nds_session_showFailure >/dev/null && nds_session_showFailure "${1:-?}"
    _nds_session_publish || return 1
}

_nds_session_onExitClean() {
    _nds_session_publish || return 1
    runtime_purgeAll || return 1
}

eventRegister exitError _nds_session_onExitError
eventRegister exitClean _nds_session_onExitClean
