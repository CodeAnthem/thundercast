#!/usr/bin/env bash
# ==================================================================================================
# NDS - QR encode helper (decoupled)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# Description:   Ensure qrencode + print payload — no labels/policy; callers own display
# ==================================================================================================

declare -g NDS_QR_READY=false

# Description: Ensure qrencode is available (PATH or nixpkgs#qrencode).
# First nix warm may show step UI and write install log lines via nds_pkg_ensure.
# Returns:
# - 0 when ready
nds_qr_ensure() {
    [[ "${NDS_QR_READY}" == "true" ]] && return 0
    nds_pkg_ensure qrencode qrencode || return 1
    NDS_QR_READY=true
    return 0
}

# Description: Print a QR code for arbitrary text to stdout.
# Does not print labels or call domain UI. Caller decides when/whether to use QR.
# Arguments:
# - payload: <String> Text to encode
# Returns:
# - 0 when a format rendered; 1 when qrencode missing or all formats failed
nds_qr_print() {
    local payload="${1:-}"
    local fmt
    local -a qr_cmd=()

    [[ -n "$payload" ]] || return 0
    nds_qr_ensure || return 1
    nds_pkg_cmd qr_cmd qrencode qrencode || return 1

    for fmt in ANSIUTF8 ANSI UTF8; do
        if "${qr_cmd[@]}" -t "$fmt" <<< "$payload" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}
