#!/usr/bin/env bash
# ==================================================================================================
# NDS - Session exit hooks
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-23 | Modified: 2026-09-27
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_nds_session_publish() {
    nds_session_logs_publish || return 1
}

_nds_session_onExitError() {
    local code="${1:-?}"
    warn "NDS failed (${code})."
    nds_logs_compose
    nds_session_showFailure "$code"
    _nds_session_publish || return 1
}

_nds_session_onExitClean() {
    info "NDS finished successfully"
    nds_logs_compose
    _nds_session_publish || return 1
    runtime_purgeAll || return 1
}

eventRegister exitError _nds_session_onExitError
eventRegister exitClean _nds_session_onExitClean
