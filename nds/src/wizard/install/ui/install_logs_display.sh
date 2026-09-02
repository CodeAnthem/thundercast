#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install UI: log fetch hints
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-08-16
# ==================================================================================================

# Description: Print scp commands to copy install logs to the operator machine.
# Publishes logs on every call; prints the scp block only once per session.
nds_install_logs_fetch_hints() {
    local user host nds_home nixos_home

    declare -f nds_install_logs_publish &>/dev/null && nds_install_logs_publish
    [[ "${_NDS_INSTALL_LOGS_HINTS_PRINTED:-}" == "1" ]] && return 0
    # Console only. Nested nds_step_exec captures stderr into install.log;
    # scp lines there hide the real error in the diagnostics tail.
    if ! nds_ui_step_tty; then
        return 0
    fi
    _NDS_INSTALL_LOGS_HINTS_PRINTED=1
    user=${ nds_lib_getSshUser; }
    host=${ nds_lib_getHostIP; }
    nds_home=${ nds_install_logs_home_nds; }
    nixos_home=${ nds_install_logs_home_nixos; }
    [[ -n "$host" ]] || return 0

    nds_ui_b "Copy logs from your local machine:"
    nds_ui_i "NDS log (session + steps + diagnostics):"
    nds_ui_i "  scp ${user}@${host}:${nds_home} ./nds.log"
    nds_ui_i "NixOS installer output:"
    nds_ui_i "  scp ${user}@${host}:${nixos_home} ./nixosInstallation.log"
    nds_ui_b ""
}
