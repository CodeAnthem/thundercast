#!/usr/bin/env bash
# ==================================================================================================
# facter utility - nixos-facter report writer + sanitize
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# ==================================================================================================

_FACTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Description: Run nixos-facter and write JSON to dest.
# Arguments:
# - dest: <String> Absolute output path
facter_write() {
    local dest="${1:?facter output path}"
    local -a cmd
    local nix_cfg="${PKG_NIX_CONFIG:-${NDS_PKG_NIX_CONFIG:-}}"

    mkdir -p "$(dirname "$dest")"
    cmd=(
        nix --extra-experimental-features "nix-command flakes"
        run nixpkgs#nixos-facter -- -o "$dest"
    )
    if [[ -n "$nix_cfg" ]]; then
        env NIX_CONFIG="$nix_cfg" "${cmd[@]}" || return 1
    else
        "${cmd[@]}" || return 1
    fi
    [[ -s "$dest" ]]
}

for f in "${_FACTER_DIR}/ops"/*.sh; do
    [[ -f "$f" ]] || continue
    # shellcheck disable=SC1090
    source "$f"
done

facter_onLoad() { return 0; }
facter_onExit() { return 0; }
