#!/usr/bin/env bash
# ==================================================================================================
# hwconfig - generate hardware-configuration.nix (no prompts)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-03
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

# Description: Hardware artifact basename for an install kind.
# Arguments:
# - kind: <String> classic | flake | other (classic → hardware-configuration.nix)
# - gen:  <String|optional> facter | legacy (flake default facter)
# Returns:
# - <String> facter.json or hardware-configuration.nix (stdout)
hwconfig_artifactName() {
    local kind="${1:-}"
    local gen="${2:-}"

    if [[ "$kind" == "classic" ]]; then
        printf '%s\n' "hardware-configuration.nix"
        return 0
    fi
    gen="${gen:-facter}"
    if [[ "$gen" == "facter" ]]; then
        printf '%s\n' "facter.json"
    else
        printf '%s\n' "hardware-configuration.nix"
    fi
}

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
