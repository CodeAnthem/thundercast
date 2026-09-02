#!/usr/bin/env bash
# ==================================================================================================
# hwconfig - generate hardware-configuration.nix (no prompts)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# ==================================================================================================

if ! declare -F error >/dev/null 2>&1; then
    error() { printf 'HWCONFIG: %s\n' "$1" >&2; }
fi
if ! declare -F err >/dev/null 2>&1; then
    err() { error "${FUNCNAME[1]:-hwconfig}: $1"; }
fi
if ! declare -F log >/dev/null 2>&1; then
    log() { printf 'HWCONFIG: %s\n' "$1" >&2; }
fi

# Description: Run nixos-generate-config --show-hardware-config into dest.
# Arguments:
# - dest:       <String> Absolute output path
# - root:       <String|optional> Target root (default /mnt)
# - detail_log: <String|optional> Stderr append path
hwconfig_generate() {
    local dest="$1"
    local root="${2:-/mnt}"
    local detail_log="${3:-${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}}"

    mkdir -p "$(dirname "$dest")"
    if ! nixos-generate-config --root "$root" --show-hardware-config >"$dest" 2>>"$detail_log"; then
        err "Failed to generate hardware configuration"
        return 1
    fi
    [[ -s "$dest" ]] || { err "hardware-configuration.nix was not written to ${dest}"; return 1; }
    return 0
}

# Compatibility name used by classic/flake shot callers.
_nds_install_generate_legacy_hardware() {
    local dest="$1"
    log "Generating hardware configuration (legacy) -> ${dest}"
    hwconfig_generate "$dest" /mnt || return 1
    log "Generated hardware-configuration.nix at ${dest}"
    return 0
}
