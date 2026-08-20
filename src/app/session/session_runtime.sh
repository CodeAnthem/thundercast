#!/usr/bin/env bash
# ==================================================================================================
# NDS - Session scratch directory
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-08-16
# Description:   Per-run RUNTIME_DIR; log path constants live in main.sh
# ==================================================================================================

# Setup runtime directory for config/secrets scratch space.
# Truncates the session log so ISO reruns do not concatenate failed attempts.
# Usage: nds_runtime_init
nds_runtime_init() {
    local timestamp=""
    printf -v timestamp '%(%Y%m%d_%H%M%S)T' -1
    [[ -n "$timestamp" ]] || return 1

    RUNTIME_DIR="/tmp/nds_${timestamp}_$$"
    mkdir -p "$RUNTIME_DIR/config" "$RUNTIME_DIR/secrets" || return 1
    chmod 700 "$RUNTIME_DIR" || return 1

    export RUNTIME_DIR
    export NDS_RUNTIME_DIR="$RUNTIME_DIR"
    export NDS_INSTALL_DETAIL_LOG="${RUNTIME_DIR}/install.log"
    export NDS_NIXOS_INSTALL_LOG="${RUNTIME_DIR}/nixosInstallation.log"
    mkdir -p "$(dirname "${NDS_INSTALL_LOG:?session log path unset}")"
    : >"$NDS_INSTALL_LOG"
    : >"$NDS_INSTALL_DETAIL_LOG"
    : >"$NDS_NIXOS_INSTALL_LOG"
    return 0
}

# Description: Remove the session runtime directory on exit.
nds_runtime_purge() {
    if [[ -d "${RUNTIME_DIR:-}" ]]; then
        if rm -rf "$RUNTIME_DIR"; then
            success " > Removed runtime directory: $RUNTIME_DIR"
        else
            error " > Failed to remove runtime directory: $RUNTIME_DIR"
        fi
    fi
}

# Description: Append a line to the session log (events, warnings, info).
# Installer command output goes to NDS_NIXOS_INSTALL_LOG; other step output
# goes to NDS_INSTALL_DETAIL_LOG. Both are merged into nds.log at publish.
# Usage: nds_install_log "message"
nds_install_log() {
    local message="$1"
    local stamp
    printf -v stamp '%(%Y-%m-%d %H:%M:%S)T' -1
    printf '%s %s\n' "$stamp" "$message" >> "${NDS_INSTALL_LOG:?session log path unset}"
}
