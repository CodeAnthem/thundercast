#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install log paths and fetch hints
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-15
# Description:   Home copies of nds.log + nixosInstallation.log; compose merged NDS log
# ==================================================================================================

# Description: Writable log root for install logs.
# Prefer /home/<user> on the live ISO; fall back to runtime temp during tests.
# Returns:
# - <String> directory path
nds_install_logs_root_dir() {
    local user home_dir fallback
    user=$(nds_lib_getSshUser)
    home_dir="/home/${user}"
    fallback="${NDS_RUNTIME_DIR:-/tmp/nds}"

    if mkdir -p "$home_dir" 2>/dev/null; then
        printf '%s\n' "$home_dir"
    else
        mkdir -p "$fallback" 2>/dev/null || true
        printf '%s\n' "$fallback"
    fi
}

# Description: Working compact diagnostics log path (folded into nds.log at publish).
# Returns:
# - <String> path (stdout)
nds_install_logs_home_diag() {
    printf '%s/nds_install_diag.log\n' "$(nds_install_logs_root_dir)"
}

# Description: Published merged NDS log path (session + steps + diagnostics).
# Returns:
# - <String> path (stdout)
nds_install_logs_home_nds() {
    printf '%s/nds.log\n' "$(nds_install_logs_root_dir)"
}

# Description: Published nixos-install / flake-build / nixos-anywhere log path.
# Returns:
# - <String> path (stdout)
nds_install_logs_home_nixos() {
    printf '%s/nixosInstallation.log\n' "$(nds_install_logs_root_dir)"
}

# Description: chown/chmod home log files for the live-ISO nixos user.
# Arguments:
# - user:  <String> Target owner (e.g. nixos)
# - paths: <String+> Files to fix
_nds_install_logs_chown_files() {
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

# Description: Write one titled section into the merged NDS log (stdout).
# Arguments:
# - title: <String> Section heading
# - note:  <String> One-line note under the heading (empty to skip)
# - src:   <String> File to append (empty/missing -> "(empty)")
_nds_install_logs_write_section() {
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
        _nds_install_logs_plain_text "$src"
        printf '\n'
    else
        printf '(empty)\n\n'
    fi
}

# Description: Copy a log file without ANSI, CR, or spinner frames.
# Arguments:
# - src: <String> Source log path
_nds_install_logs_plain_text() {
    local src="$1"

    # Strip CSI / OSC / CR, then drop leftover spinner frames ([||] [//] [--] [\\]).
    sed -e 's/\r//g' \
        -e 's/\x1b\[[0-9;:?]*[A-Za-z]//g' \
        -e 's/\x1b][^\x07]*\x07//g' \
        "$src" \
        | grep -vE '\[\|\|\]|\[//\]|\[--\]|\[\\\\\]' \
        || true
}

# Description: Merge session, install-step, and diagnostics logs into one file.
# Does not include nixos-install output; that stays in nixosInstallation.log.
# Arguments:
# - dest:    <String> Output path
# - session: <String> Session log path (default: NDS_INSTALL_LOG)
# - detail:  <String> Step log path (default: NDS_INSTALL_DETAIL_LOG)
# - diag:    <String> Diagnostics log path (default: NDS_INSTALL_DIAG_LOG)
nds_install_logs_compose() {
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

        _nds_install_logs_write_section \
            "1. Session" \
            "NDS events, warnings, and info from this run." \
            "$session"

        _nds_install_logs_write_section \
            "2. Install steps" \
            "Partitioning, mounts, hardware config, and other NDS steps. NixOS installer output: see logs/nixosInstallation.log" \
            "$detail"

        _nds_install_logs_write_section \
            "3. Diagnostics" \
            "Compact snapshots (disk, mounts, profiles, failures)." \
            "$diag"
    } >"$dest"
}

# Description: Point diag log at /home/nixos and create nixos-owned log files.
nds_install_logs_init() {
    local user diag_home nds_home nixos_home

    user=$(nds_lib_getSshUser)
    diag_home=$(nds_install_logs_home_diag)
    nds_home=$(nds_install_logs_home_nds)
    nixos_home=$(nds_install_logs_home_nixos)
    : >"$diag_home"
    : >"$nds_home"
    : >"$nixos_home"
    _nds_install_logs_chown_files "$user" "$diag_home" "$nds_home" "$nixos_home"
    export NDS_INSTALL_DIAG_LOG="$diag_home"
}

# Description: Compose nds.log and copy nixosInstallation.log into /home/nixos.
nds_install_logs_publish() {
    local user diag_home nds_home nixos_home

    user=$(nds_lib_getSshUser)
    diag_home=$(nds_install_logs_home_diag)
    nds_home=$(nds_install_logs_home_nds)
    nixos_home=$(nds_install_logs_home_nixos)

    nds_install_logs_compose "$nds_home"

    if [[ -f "${NDS_NIXOS_INSTALL_LOG:-}" && "${NDS_NIXOS_INSTALL_LOG}" != "$nixos_home" ]]; then
        cp "${NDS_NIXOS_INSTALL_LOG}" "$nixos_home"
    elif [[ ! -f "$nixos_home" ]]; then
        : >"$nixos_home"
    fi

    _nds_install_logs_chown_files "$user" "$diag_home" "$nds_home" "$nixos_home"
}
