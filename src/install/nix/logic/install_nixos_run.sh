#!/usr/bin/env bash
# ==================================================================================================
# NDS - Classic nixos-install runner
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-08-16
# Description:   Copy generated configs onto /mnt and run nixos-install
# ==================================================================================================

# Description: Copy generated Nix configs into /mnt/etc/nixos for nixos-install.
_nds_install_configs() {
    mkdir -p /mnt/etc/nixos
    cp "$NDS_RUNTIME_DIR/config/"*.nix /mnt/etc/nixos/ || return 1
    return 0
}

# Install NixOS system
# Usage: _nds_install_nixos
_nds_install_nixos() {
    local nixos_log="${NDS_NIXOS_INSTALL_LOG:-/tmp/nds_nixosInstallation.log}"

    log "Installing NixOS system"

    if [[ ! -f /mnt/etc/nixos/configuration.nix ]]; then
        error "No configuration.nix found - run nds_nixcfg_write first"
        return 1
    fi

    if ! nixos-install --root /mnt --no-root-passwd; then
        error "NixOS installation failed — last lines of ${nixos_log}:"
        tail -n 30 "$nixos_log" 2>/dev/null | while IFS= read -r _line; do
            printf '%s  %s\n' "${NDS_UI_INDENT_I:-}" "$_line" >&2
        done || true
        return 1
    fi

    nds_nix_ensure_install_artifacts || return 1

    log "NixOS installation completed"
    return 0
}
