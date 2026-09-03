#!/usr/bin/env bash
# ==================================================================================================
# NDS realize - hardware artifact steps (facter.json / hardware-configuration.nix)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-09-03
# ==================================================================================================

# Description: Artifact basename for the current INSTALL_KIND (classic → legacy, flake → facter).
# Returns:
# - <String> facter.json | hardware-configuration.nix (stdout)
_nds_realize_hw_artifact_name() {
    nds_requireUtility hwconfig || return 1
    hwconfig_artifactName "${ nds_realize_kind; }" "${NDS_HARDWARE_GEN:-}"
}

# Description: Write one hardware artifact at dest (dispatch by basename).
# Arguments:
# - dest: <String> Absolute output path
_nds_realize_write_hardware() {
    local dest="$1" nix_config

    mkdir -p "$(dirname "$dest")"
    if [[ "$(basename "$dest")" == "facter.json" ]]; then
        nds_requireUtility pkg || return 1
        nds_requireUtility facter || return 1
        nds_requireUtility nixos || return 1
        nix_config=${ nixos_combinedNixConfig "experimental-features = nix-command flakes"; }
        log "Generating hardware report via nixos-facter -> ${dest}"
        if ! NDS_PKG_NIX_CONFIG="$nix_config" PKG_NIX_CONFIG="$nix_config" facter_write "$dest" \
            >>"${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}" 2>&1; then
            error "nixos-facter failed — see install log for details"
            return 1
        fi
        facter_sanitize "$dest" || { error "Failed to sanitize facter.json (null scrub)"; return 1; }
    else
        nds_requireUtility hwconfig || return 1
        log "Generating hardware configuration -> ${dest}"
        hwconfig_generate "$dest" /mnt || return 1
    fi
    chmod 600 "$dest" || return 1
    return 0
}

# Description: Classic: hardware-configuration.nix on the target + copy into runtime config dir.
# Arguments:
# - etc_nixos:   <String> Target /etc/nixos (mounted)
# - runtime_cfg: <String> Runtime config dir (bundled)
_nds_realize_classic_hardware() {
    local etc_nixos="$1" runtime_cfg="$2"
    local dest="${etc_nixos}/hardware-configuration.nix"

    mkdir -p "$etc_nixos" "$runtime_cfg"
    [[ -s "$dest" ]] || _nds_realize_write_hardware "$dest" || return 1
    cp "$dest" "${runtime_cfg}/hardware-configuration.nix" || return 1
    return 0
}

# Description: Flake: write the hardware artifact to host-dir or /mnt/etc/nixos; mirror to runtime.
# Asks before overwriting an existing host-dir artifact.
# Arguments:
# - host_dir: <String> Flake host directory
# - hw_mode:  <String> host-dir | etc-nixos
_nds_realize_place_hardware() {
    local host_dir="$1" hw_mode="${2:-host-dir}"
    local artifact dest

    artifact=${ _nds_realize_hw_artifact_name; } || return 1
    case "$hw_mode" in
        etc-nixos) dest="/mnt/etc/nixos/${artifact}" ;;
        host-dir|*)
            mkdir -p "$host_dir"
            dest="${host_dir}/${artifact}"
            if [[ -f "$dest" ]]; then
                NDS_UI_QUIET=false
                warn "${artifact} already exists: $dest"
                if ! nds_install_ui_confirm_hardware_overwrite "$artifact"; then
                    NDS_UI_QUIET=true
                    log "Keeping existing ${artifact}"
                    mkdir -p "${NDS_RUNTIME_DIR}/config"
                    cp "$dest" "${NDS_RUNTIME_DIR}/config/" 2>/dev/null || true
                    return 0
                fi
                NDS_UI_QUIET=true
            fi
            ;;
    esac

    _nds_realize_write_hardware "$dest" || return 1
    mkdir -p "${NDS_RUNTIME_DIR}/config"
    cp "$dest" "${NDS_RUNTIME_DIR}/config/" || return 1
    return 0
}
