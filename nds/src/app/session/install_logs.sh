#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install log paths and publish
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-09-25
# Description:   Home copies of nds.log and nixosInstallation.log. Not called from exit yet.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_nds_session_logs_user() {
    local user="${SUDO_USER:-nixos}"
    [[ "$user" == root ]] && user=nixos
    printf '%s\n' "$user"
}

# Writable log root. Prefer /home/<user>; fall back to the runtime temp dir.
nds_session_logs_root_dir() {
    local user home_dir fallback
    user="${ _nds_session_logs_user; }"
    home_dir="/home/${user}"
    fallback="${TMPDIR:-/tmp}/nds"

    if mkdir -p "$home_dir" 2>/dev/null; then
        printf '%s\n' "$home_dir"
    else
        mkdir -p "$fallback" 2>/dev/null || true
        printf '%s\n' "$fallback"
    fi
}

nds_session_logs_home_diag() {
    printf '%s/nds_install_diag.log\n' "${ nds_session_logs_root_dir; }"
}

nds_session_logs_home_nds() {
    printf '%s/nds.log\n' "${ nds_session_logs_root_dir; }"
}

nds_session_logs_home_nixos() {
    printf '%s/nixosInstallation.log\n' "${ nds_session_logs_root_dir; }"
}

_nds_session_logs_chown_files() {
    local user="$1"
    shift
    local path

    [[ -n "$user" ]] || return 0
    for path in "$@"; do
        [[ -e "$path" ]] || continue
        chown "$user" "$path" 2>/dev/null || true
        chmod 600 "$path" 2>/dev/null || true
    done
}

_nds_session_logs_plain_text() {
    local src="$1"
    sed -e 's/\r//g' \
        -e 's/\x1b\[[0-9;:?]*[A-Za-z]//g' \
        -e 's/\x1b][^\x07]*\x07//g' \
        "$src" \
        | grep -vE '\[\|\|\]|\[//\]|\[--\]|\[\\\\\]' \
        || true
}

_nds_session_logs_write_section() {
    local title="$1"
    local note="$2"
    local src="${3:-}"

    printf '%s\n' "--------------------------------------------------------------------------------"
    printf '%s\n' "${title}"
    printf '%s\n' "--------------------------------------------------------------------------------"
    if [[ -n "$note" ]]; then
        printf '%s\n' "${note}"
        printf '\n'
    fi
    if [[ -n "$src" && -s "$src" ]]; then
        _nds_session_logs_plain_text "$src"
        printf '\n'
    else
        printf '(empty)\n\n'
    fi
}

# Merge session, step, and diagnostics logs. NixOS installer output stays separate.
nds_session_logs_compose() {
    local dest="$1"
    local session="${2:-${NDS_INSTALL_LOG:-}}"
    local detail="${3:-${NDS_INSTALL_DETAIL_LOG:-}}"
    local diag="${4:-${NDS_INSTALL_DIAG_LOG:-}}"

    [[ -n "$dest" ]] || return 1
    mkdir -p "$(dirname "$dest")"

    {
        printf '%s\n' "================================================================================"
        printf '%s\n' "NDS log"
        printf '%s\n' "================================================================================"
        printf '%s\n' "Combined session events, install steps, and diagnostics."
        printf '%s\n' "NixOS installer output is not included — see logs/nixosInstallation.log"
        printf '\n'

        _nds_session_logs_write_section \
            "1. Session" \
            "NDS events, warnings, and info from this run." \
            "$session"

        _nds_session_logs_write_section \
            "2. Install steps" \
            "Partitioning, mounts, hardware config, and other NDS steps. NixOS installer output: see logs/nixosInstallation.log" \
            "$detail"

        _nds_session_logs_write_section \
            "3. Diagnostics" \
            "Compact snapshots (disk, mounts, profiles, failures)." \
            "$diag"
    } >"$dest"
}

nds_session_logs_init() {
    local user diag_home nds_home nixos_home

    user="${ _nds_session_logs_user; }"
    diag_home="${ nds_session_logs_home_diag; }"
    nds_home="${ nds_session_logs_home_nds; }"
    nixos_home="${ nds_session_logs_home_nixos; }"
    : >"$diag_home"
    : >"$nds_home"
    : >"$nixos_home"
    _nds_session_logs_chown_files "$user" "$diag_home" "$nds_home" "$nixos_home"
    export NDS_INSTALL_DIAG_LOG="$diag_home"
}

nds_session_logs_publish() {
    local user diag_home nds_home nixos_home

    user="${ _nds_session_logs_user; }"
    diag_home="${ nds_session_logs_home_diag; }"
    nds_home="${ nds_session_logs_home_nds; }"
    nixos_home="${ nds_session_logs_home_nixos; }"

    nds_session_logs_compose "$nds_home"

    if [[ -f "${NDS_NIXOS_INSTALL_LOG:-}" && "${NDS_NIXOS_INSTALL_LOG}" != "$nixos_home" ]]; then
        cp "${NDS_NIXOS_INSTALL_LOG}" "$nixos_home"
    elif [[ ! -f "$nixos_home" ]]; then
        : >"$nixos_home"
    fi

    _nds_session_logs_chown_files "$user" "$diag_home" "$nds_home" "$nixos_home"
}
