#!/usr/bin/env bash
# ==================================================================================================
# NDS - Failed-run log tails
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-09-25
# Description:   Banner plus the last lines of the installer and diagnostics logs.
#                Not registered on exitError. The exit hook still prints the one-line warning.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_nds_session_tail() {
    local path="$1" lines="$2" line
    [[ -f "$path" ]] || return 0
    while IFS= read -r line; do
        ui_i "$line"
    done < <(tail -n "$lines" "$path" 2>/dev/null)
}

nds_session_showFailure() {
    local exit_code="${1:-?}"
    local log="${NDS_INSTALL_DETAIL_LOG:-}"
    local nixos="${NDS_NIXOS_INSTALL_LOG:-}"

    ui_warn "Installation failed (exit code ${exit_code})."
    if [[ -n "$nixos" && -s "$nixos" ]]; then
        ui_i "NixOS installer log: ${nixos}"
        ui_b "Last lines:"
        _nds_session_tail "$nixos" 12
        ui_b ""
    elif [[ -n "$log" && -f "$log" ]]; then
        ui_i "Full log: ${log}"
        ui_b "Last lines:"
        _nds_session_tail "$log" 12
        ui_b ""
    fi
    if [[ -f "${NDS_INSTALL_DIAG_LOG:-}" ]]; then
        ui_b "Diagnostics (last lines):"
        _nds_session_tail "${NDS_INSTALL_DIAG_LOG}" 24
        ui_b ""
    fi
}
