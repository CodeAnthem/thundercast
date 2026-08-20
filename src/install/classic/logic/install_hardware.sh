#!/usr/bin/env bash
# ==================================================================================================
# NDS - Hardware artifact generation (facter / nixos-generate-config)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-08-16
# Description:   Write facter.json or hardware-configuration.nix for classic and flake
# ==================================================================================================

# Returns:
# - <String> facter.json or hardware-configuration.nix
# Classic install always needs hardware-configuration.nix (configuration.nix imports it).
# Flake installs default to facter.json unless NDS_HARDWARE_GEN=legacy.
_nds_install_hardware_artifact_name() {
    local facter_mode="${NDS_HARDWARE_GEN:-}"

    if [[ "${NDS_CURRENT_ACTION:-}" == "classicInstall" ]]; then
        printf '%s\n' "hardware-configuration.nix"
        return 0
    fi

    facter_mode="${facter_mode:-facter}"
    if [[ "$facter_mode" == "facter" ]]; then
        printf '%s\n' "facter.json"
    else
        printf '%s\n' "hardware-configuration.nix"
    fi
}


# Description: Drop null holes from a nixos-facter JSON report.
# VMware guests often emit hardware.cpu = [ null, null, …, {…} ]; nixpkgs
# hardware/facter/virtualisation.nix then fails with: expected a set but found null.
# Arguments:
# - dest: <String> Absolute path to facter.json (rewritten in place)
_nds_install_sanitize_facter_report() {
    local dest="$1"
    local tmp

    [[ -s "$dest" ]] || return 1
    tmp=$(mktemp)
    if ! nix --extra-experimental-features 'nix-command flakes' eval --impure --json \
        --expr "
let
  report = builtins.fromJSON (builtins.readFile \"${dest}\");
  scrub = v:
    if builtins.isList v then
      map scrub (builtins.filter (x: x != null) v)
    else if builtins.isAttrs v then
      builtins.mapAttrs (_: scrub) v
    else
      v;
in scrub report
" >"$tmp" 2>>"${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"; then
        rm -f "$tmp"
        error "Failed to sanitize facter.json (null scrub) — see install log"
        return 1
    fi
    mv -f "$tmp" "$dest"
    return 0
}

# Description: Generate facter.json at dest via nixos-facter (live-ISO hardware scan).
# Arguments:
# - dest: <String> Absolute output path (e.g. .../facter.json)
_nds_install_generate_facter_report() {
    local dest="$1"
    mkdir -p "$(dirname "$dest")"
    log "Generating hardware report via nixos-facter -> ${dest}"
    local nix_config
    nix_config=$(_nds_install_nix_combined_nix_config "experimental-features = nix-command flakes")
    if ! NDS_PKG_NIX_CONFIG="$nix_config" nds_facter_write "$dest" \
        >>"${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}" 2>&1; then
        error "nixos-facter failed — see install log for details"
        return 1
    fi
    _nds_install_sanitize_facter_report "$dest" || return 1
    log "Generated facter.json at ${dest}"
    return 0
}

# Description: Generate legacy hardware-configuration.nix at dest.
# Arguments:
# - dest: <String> Absolute output path
_nds_install_generate_legacy_hardware() {
    local dest="$1"
    local detail_log="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"

    mkdir -p "$(dirname "$dest")"
    log "Generating hardware configuration (legacy) -> ${dest}"
    # stdout must go only to dest; do not also >> detail_log (that emptied dest).
    if ! nixos-generate-config --root /mnt --show-hardware-config >"$dest" 2>>"$detail_log"; then
        error "Failed to generate hardware configuration"
        return 1
    fi
    if [[ ! -s "$dest" ]]; then
        error "hardware-configuration.nix was not written to ${dest}"
        return 1
    fi
    log "Generated hardware-configuration.nix at ${dest}"
    return 0
}

# Description: Write the hardware artifact for a flake install (host-dir / etc-nixos).
# Arguments:
# - host_dir:      <String> Flake host directory (for host-dir placement)
# - hw_mode:       <String> host-dir | etc-nixos | skip
# - runtime_copy:  <Bool> When true, mirror into $NDS_RUNTIME_DIR/config/ for backup
_nds_install_place_hardware_artifact() {
    local host_dir="$1"
    local hw_mode="${2:-host-dir}"
    local runtime_copy="${3:-true}"
    local hw_artifact dest

    hw_artifact=$(_nds_install_hardware_artifact_name)

    case "$hw_mode" in
        skip)
            log "Skipping ${hw_artifact} (FLAKE_HARDWARE_PLACEMENT=skip)"
            return 0
            ;;
        etc-nixos)
            dest="/mnt/etc/nixos/${hw_artifact}"
            ;;
        host-dir|*)
            mkdir -p "$host_dir"
            dest="${host_dir}/${hw_artifact}"
            if [[ -f "$dest" ]]; then
                NDS_UI_QUIET=false
                warn "${hw_artifact} already exists: $dest"
                if ! nds_install_ui_confirm_hardware_overwrite "$hw_artifact"; then
                    log "Keeping existing ${hw_artifact}"
                    NDS_UI_QUIET=true
                    [[ "$runtime_copy" == true ]] && cp "$dest" "${NDS_RUNTIME_DIR}/config/" 2>/dev/null || true
                    return 0
                fi
                NDS_UI_QUIET=true
            fi
            ;;
    esac

    if [[ "$hw_artifact" == "facter.json" ]]; then
        _nds_install_generate_facter_report "$dest" || return 1
    else
        _nds_install_generate_legacy_hardware "$dest" || return 1
    fi
    chmod 600 "$dest" || return 1

    if [[ "$runtime_copy" == true ]]; then
        mkdir -p "${NDS_RUNTIME_DIR}/config"
        cp "$dest" "${NDS_RUNTIME_DIR}/config/" || return 1
    fi
    return 0
}

# Generate hardware configuration
# Usage: _nds_install_generate_hardware_config
_nds_install_generate_hardware_config() {
    local hw_artifact
    hw_artifact=$(_nds_install_hardware_artifact_name)
    mkdir -p /mnt/etc/nixos
    if [[ "$hw_artifact" == "facter.json" ]]; then
        _nds_install_generate_facter_report "/mnt/etc/nixos/${hw_artifact}" || return 1
    else
        _nds_install_generate_legacy_hardware "/mnt/etc/nixos/${hw_artifact}" || return 1
    fi
    return 0
}

# Description: Ensure classicInstall has hardware-configuration.nix on /mnt and in runtime.
# Regenerates with legacy nixos-generate-config when only facter.json exists (or nothing).
_nds_install_classic_ensure_hardware_config() {
    local dest="/mnt/etc/nixos/hardware-configuration.nix"

    mkdir -p /mnt/etc/nixos "${NDS_RUNTIME_DIR}/config"
    if [[ ! -s "$dest" ]]; then
        _nds_install_generate_legacy_hardware "$dest" || return 1
        chmod 600 "$dest" || return 1
    fi
    cp "$dest" "${NDS_RUNTIME_DIR}/config/hardware-configuration.nix" || return 1
    return 0
}
