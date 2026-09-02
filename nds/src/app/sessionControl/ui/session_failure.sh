#!/usr/bin/env bash
# ==================================================================================================
# NDS - App UI: failed-exit diagnostics display
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-08-14
# ==================================================================================================

# Description: Print failure banner + log tails after a non-zero exit.
# Arguments:
# - exit_code: <Int> Process exit code
nds_app_session_ui_showFailure() {
    local exit_code="$1"
    nds_ui_init
    if [[ "$NDS_UI_COLOR" == true ]]; then
        printf '%s\033[31;1mInstallation failed (exit code %s).\033[0m\n' "$NDS_UI_INDENT_B" "$exit_code" >&2
    else
        printf '%sInstallation failed (exit code %s).\n' "$NDS_UI_INDENT_B" "$exit_code" >&2
    fi
    nds_ui_b ""
    if declare -f nds_install_logs_fetch_hints &>/dev/null; then
        nds_install_logs_fetch_hints
    else
        local log="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
        local nixos="${NDS_NIXOS_INSTALL_LOG:-}"
        if [[ -n "$nixos" && -s "$nixos" ]]; then
            nds_ui_i "NixOS installer log: ${nixos}"
            nds_ui_b "Last lines:"
            while IFS= read -r _line; do
                printf '%s  %s\n' "${NDS_UI_INDENT_I:-}" "$_line" >&2
            done < <(tail -n 12 "$nixos" 2>/dev/null)
            nds_ui_b ""
        elif [[ -f "$log" ]]; then
            nds_ui_i "Full log: ${log}"
            nds_ui_b "Last lines:"
            while IFS= read -r _line; do
                printf '%s  %s\n' "${NDS_UI_INDENT_I:-}" "$_line" >&2
            done < <(tail -n 12 "$log" 2>/dev/null)
            nds_ui_b ""
        fi
    fi
    if [[ -f "${NDS_INSTALL_DIAG_LOG:-}" ]]; then
        nds_ui_b "Diagnostics (last lines):"
        while IFS= read -r _line; do
            printf '%s  %s\n' "${NDS_UI_INDENT_I:-}" "$_line" >&2
        done < <(tail -n 24 "${NDS_INSTALL_DIAG_LOG}" 2>/dev/null)
        nds_ui_b ""
    fi
}
