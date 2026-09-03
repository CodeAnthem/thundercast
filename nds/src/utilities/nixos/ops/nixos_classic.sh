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
    local nixos_log="${NDS_NIXOS_INSTALL_LOG:-/tmp/nds_nixosInstallation.log}"

    [[ -f "${root}/etc/nixos/configuration.nix" ]] || {
        err "No configuration.nix under ${root}/etc/nixos"
        return 1
    }

    if ! nixos-install --root "$root" --no-root-passwd; then
        error "NixOS installation failed — last lines of ${nixos_log}:"
        tail -n 30 "$nixos_log" 2>/dev/null | while IFS= read -r _line; do
            printf '%s  %s\n' "${NDS_UI_INDENT_I:-}" "$_line" >&2
        done || true
        return 1
    fi
    return 0
}
