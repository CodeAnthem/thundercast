#!/usr/bin/env bash
# ==================================================================================================
# nixos utility - store helpers + nixos-install / flake build runners (no step UI, no prompts)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-03
# Description:   Caller sets boot context once (nixos_setBootContext); every op is argument-driven.
# ==================================================================================================

if (( BASH_VERSINFO[0] < 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] < 3) )); then
    printf 'NIXOS: requires Bash 5.3 or newer (found %s).\n' "${BASH_VERSION}" >&2
    return 1 2>/dev/null || exit 1
fi

if ! declare -F error >/dev/null 2>&1; then
    error() { printf 'NIXOS: %s\n' "$1" >&2; }
fi
if ! declare -F err >/dev/null 2>&1; then
    err() { error "${FUNCNAME[1]:-nixos}: $1"; }
fi
if ! declare -F log >/dev/null 2>&1; then
    log() { printf 'NIXOS: %s\n' "$1" >&2; }
fi
if ! declare -F warn >/dev/null 2>&1; then
    warn() { printf 'NIXOS: warn: %s\n' "$1" >&2; }
fi
if ! declare -F info >/dev/null 2>&1; then
    info() { printf 'NIXOS: %s\n' "$1" >&2; }
fi
if ! declare -F nds_install_log >/dev/null 2>&1; then
    nds_install_log() { printf 'NIXOS: %s\n' "$1" >&2; }
fi

_NIXOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Boot context for bootloader repair / remount (set by the caller, never read from settings).
declare -g _NIXOS_BOOT_LOADER="grub"
declare -g _NIXOS_BOOT_UEFI=""
declare -g _NIXOS_DISK=""
declare -g _NIXOS_ENCRYPTION="false"

# Description: Set the boot context used by bootloader repair and remount.
# Arguments:
# - loader:     <String> grub | systemd-boot | refind
# - uefi:       <String> true | false | "" (detect)
# - disk:       <String> Target block device
# - encryption: <String> true | false
nixos_setBootContext() {
    _NIXOS_BOOT_LOADER="${1:-grub}"
    _NIXOS_BOOT_UEFI="${2:-}"
    _NIXOS_DISK="${3:-}"
    _NIXOS_ENCRYPTION="${4:-false}"
}

_nixos_source_dir() {
    local dir="$1" f
    for f in "$dir"/*.sh; do
        [[ -f "$f" ]] || continue
        # shellcheck disable=SC1090
        source "$f"
    done
}

_nixos_source_dir "${_NIXOS_DIR}/ops"

nixos_onLoad() { return 0; }
nixos_onExit() { return 0; }
