#!/usr/bin/env bash
# ==================================================================================================
# QR utility - encode payload (PATH / QR_BIN; no UI)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# ==================================================================================================

# Description: Resolve qrencode binary (QR_BIN or PATH).
# Returns:
# - <String> Absolute or command name (stdout)
# - <Bool> 0 when found
qr_bin() {
    if [[ -n "${QR_BIN:-}" && -x "${QR_BIN}" ]]; then
        printf '%s' "$QR_BIN"
        return 0
    fi
    command -v qrencode 2>/dev/null
}

# Description: True when qrencode is available.
# Returns:
# - <Bool> 0 when ready
qr_isAvailable() {
    qr_bin >/dev/null
}

# Description: Print a QR code for arbitrary text to stdout (no labels).
# Arguments:
# - payload: <String> Text to encode
# Returns:
# - <Bool> 0 when a format rendered
qr_print() {
    local payload="${1:-}" bin fmt
    [[ -n "$payload" ]] || return 0
    bin=${ qr_bin; } || return 1
    for fmt in ANSIUTF8 ANSI UTF8; do
        if "$bin" -t "$fmt" <<< "$payload" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}

qr_onLoad() { return 0; }
qr_onExit() { return 0; }
