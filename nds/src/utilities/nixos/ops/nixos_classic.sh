#!/usr/bin/env bash
# ==================================================================================================
# nixos - classic nixos-install runner (configuration.nix on target)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-09-03
# ==================================================================================================

# Description: Copy generated *.nix files into <root>/etc/nixos.
# Arguments:
# - src_dir: <String> Directory holding configuration.nix (+ hardware file)
# - root:    <String|optional> Target root (default /mnt)
nixos_copyConfigs() {
    local src_dir="$1"
    local root="${2:-/mnt}"

    [[ -d "$src_dir" ]] || { err "config dir missing: ${src_dir}"; return 1; }
    mkdir -p "${root}/etc/nixos"
    cp "${src_dir}/"*.nix "${root}/etc/nixos/" || return 1
    return 0
}

# Description: Run nixos-install against <root>/etc/nixos/configuration.nix.
# Arguments:
# - root: <String|optional> Target root (default /mnt)
# Returns:
# - <Bool> 0 on success
nixos_installClassic() {
    local root="${1:-/mnt}"
    local install_log
    install_log=${ nixos_installLog; }

    [[ -f "${root}/etc/nixos/configuration.nix" ]] || {
        err "No configuration.nix under ${root}/etc/nixos"
        return 1
    }
    debug "Installing NixOS to ${root}: ${install_log}"
    if ! nixos-install --root "$root" --no-root-passwd >>"$install_log" 2>&1; then
        error "nixos-install failed. Log: ${install_log}"
        return 1
    fi
    debug "nixos-install finished"
    return 0
}
