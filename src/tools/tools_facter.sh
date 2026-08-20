#!/usr/bin/env bash
# ==================================================================================================
# NDS - nixos-facter helper (decoupled)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# Description:   Write a hardware report via nixpkgs#nixos-facter — no install UI
# ==================================================================================================

# Description: Run nixos-facter and write JSON to dest.
# Arguments:
# - dest: <String> Absolute output path
# Returns:
# - 0 when dest is non-empty
nds_facter_write() {
    local dest="${1:?facter output path}"
    local -a cmd

    mkdir -p "$(dirname "$dest")"
    cmd=(
        nix --extra-experimental-features "nix-command flakes"
        run nixpkgs#nixos-facter -- -o "$dest"
    )
    if [[ -n "${NDS_PKG_NIX_CONFIG:-}" ]]; then
        env NIX_CONFIG="$NDS_PKG_NIX_CONFIG" "${cmd[@]}" || return 1
    else
        "${cmd[@]}" || return 1
    fi
    [[ -s "$dest" ]]
}
