#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-08-16
# Description:   NixOS Configuration Builder - Registry and Merger
# Feature:       Priority-based block assembly for NixOS configuration files
# ==================================================================================================

# =============================================================================
# GLOBAL REGISTRY
# =============================================================================
declare -gA NDS_NIXCFG_BLOCKS
declare -g NDS_NIXCFG_HEADER=""

# =============================================================================
# PRIORITY RANGES (with gaps for injection)
# =============================================================================
# 10-19: Boot / LUKS / remote unlock
# 20-29: Network
# 30-39: Region (timezone, locale, keyboard)
# 40-49: Access (users, sudo, SSH)
# 50-59: Packages / virtualisation
# 70-79: Nix (flakes)
# 90-99: stateVersion (written by nds_nixcfg_write)

# =============================================================================
# PUBLIC API
# =============================================================================

# Description: NDS version for the generated configuration header.
# Returns:
# - <String> semver or "unknown"
_nds_nixcfg_nds_version() {
    local ver="${SCRIPT_VERSION:-}"

    if [[ -z "$ver" && -n "${APP_DIR:-}" && -f "${APP_DIR}/VERSION" ]]; then
        ver=$(<"${APP_DIR}/VERSION")
    fi
    if [[ -z "$ver" && -n "${SCRIPT_DIR:-}" && -f "${SCRIPT_DIR}/app/VERSION" ]]; then
        ver=$(<"${SCRIPT_DIR}/app/VERSION")
    fi
    printf '%s\n' "${ver:-unknown}"
}

# Description: NixOS release to write as system.stateVersion.
# Prefers NDS_NIXOS_STATE_VERSION, then the installer ISO (nixos-version /
# NixOS os-release). Never uses a foreign host's os-release (e.g. WSL).
# Returns:
# - <String> MAJOR.MINOR, or empty when undetectable
_nds_nixcfg_state_version() {
    local ver="${NDS_NIXOS_STATE_VERSION:-}"

    if [[ "$ver" =~ ^[0-9]+\.[0-9]+$ ]]; then
        printf '%s\n' "$ver"
        return 0
    fi
    ver=""
    if command -v nixos-version &>/dev/null; then
        ver=$(nixos-version 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+' | head -1 || true)
    fi
    if [[ -z "$ver" && -r /etc/os-release ]]; then
        ver=$(awk -F= '
            $1 == "ID" { id = $2; gsub(/"/, "", id) }
            $1 == "VERSION_ID" { vid = $2; gsub(/"/, "", vid) }
            END { if (id == "nixos") print vid }
        ' /etc/os-release)
    fi
    if [[ "$ver" =~ ^[0-9]+\.[0-9]+$ ]]; then
        printf '%s\n' "$ver"
        return 0
    fi
    return 1
}

# Description: File header for classic configuration.nix (vanilla intro + NDS).
_nds_nixcfg_file_header() {
    local ver
    ver=${ _nds_nixcfg_nds_version; }
    cat <<EOF
# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').
#
# Installed with Nix Deploy System (NDS) v${ver}
# https://github.com/CodeAnthem/thundercast
EOF
}

# Description: One-line note under a section heading.
# Arguments:
# - name: <String> Block name
# Returns:
# - <String> Note (may be empty)
_nds_nixcfg_section_note() {
    case "$1" in
        boot) printf '%s\n' "Bootloader." ;;
        luks) printf '%s\n' "LUKS unlock (USB keyfile)." ;;
        remoteUnlock) printf '%s\n' "Initrd SSH remote unlock." ;;
        network) printf '%s\n' "Hostname, NetworkManager, DNS, and firewall." ;;
        region) printf '%s\n' "Timezone, locale, and keyboard." ;;
        access) printf '%s\n' "Admin user, sudo, and SSH." ;;
        packages) printf '%s\n' "System packages (edit this list as needed)." ;;
        virtualisation) printf '%s\n' "VM guest tools." ;;
        nix) printf '%s\n' "Enable flakes and the nix command." ;;
        *) ;;
    esac
}

# Description: Replace @@TOKEN@@ placeholders in a Nix block (literal, no eval).
# Arguments:
# - content: <String> Block text
# - pairs:   <String...> @@TOKEN@@ value …
# Returns:
# - <String> Substituted text (stdout)
nds_nixcfg_subst() {
    local content="$1"; shift
    while [[ $# -gt 0 ]]; do
        content="${content//"$1"/$2}"; shift 2
    done
    printf '%s' "$content"
}

# Description: Register a configuration.nix block (lower priority = earlier).
# Arguments:
# - block_name: <String> Section name
# - block_content: <String> Nix text
# - priority: <Int|optional> 0–100 (default 50)
nds_nixcfg_register() {
    local block_name="$1"
    local block_content="$2"
    local priority="${3:-50}"
    
    NDS_NIXCFG_BLOCKS["$(printf '%03d' "$priority")_${block_name}"]="$block_content"
    debug "Registered NixOS config block: $block_name (priority: $priority)"
}

# Description: Merge registered blocks into configuration.nix (includes stateVersion).
# Arguments:
# - output_file: <String|optional> Destination path
nds_nixcfg_write() {
    local output_file="${1:-/mnt/etc/nixos/configuration.nix}"
    local state_ver note

    mkdir -p "$(dirname "$output_file")"

    [[ -n "$NDS_NIXCFG_HEADER" ]] || NDS_NIXCFG_HEADER="${ _nds_nixcfg_file_header; }"
    state_ver="${ _nds_nixcfg_state_version; }" || true
    if [[ ! "$state_ver" =~ ^[0-9]+\.[0-9]+$ ]]; then
        error "Cannot determine system.stateVersion (set NDS_NIXOS_STATE_VERSION=MAJOR.MINOR)"
        return 1
    fi

    {
        if [[ -n "$NDS_NIXCFG_HEADER" ]]; then
            printf '%s\n' "$NDS_NIXCFG_HEADER"
            printf '\n'
        fi

        echo "{ config, pkgs, ... }:"
        echo ""
        echo "{"
        echo "  imports ="
        echo "    [ # Include the results of the hardware scan."
        echo "      ./hardware-configuration.nix"
        echo "    ];"
        echo ""

        for key in $(printf '%s\n' "${!NDS_NIXCFG_BLOCKS[@]}" | sort); do
            local block_name="${key#*_}"
            echo "  # === ${block_name} ==="
            note=${ _nds_nixcfg_section_note "$block_name"; }
            [[ -n "$note" ]] && echo "  # ${note}"
            printf '%s\n' "${NDS_NIXCFG_BLOCKS[$key]}" | sed 's/^/  /'
            echo ""
        done

        echo "  # === system ==="
        echo "  # NixOS release this install was first created with."
        echo "  # This value determines the NixOS release from which the default"
        echo "  # settings for stateful data, like file locations and database versions"
        echo "  # on your system were taken. It's perfectly fine and recommended to leave"
        echo "  # this value at the release version of the first install of this system."
        echo "  # Before changing this value read the documentation for this option"
        echo "  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html)."
        echo "  system.stateVersion = \"${state_ver}\"; # Did you read the comment?"
        echo ""

        echo "}"
    } > "$output_file"

    log "NixOS configuration written to: $output_file"
}

# Description: Merge registered blocks into a standalone NixOS module file.
# Arguments:
# - output_file: <String> Destination path
nds_nixcfg_write_module() {
    local output_file="$1"

    mkdir -p "$(dirname "$output_file")"

    {
        echo '{ config, lib, pkgs, ... }: {'
        for key in $(printf '%s\n' "${!NDS_NIXCFG_BLOCKS[@]}" | sort); do
            local block_name="${key#*_}"
            echo "  # === ${block_name} ==="
            printf '%s\n' "${NDS_NIXCFG_BLOCKS[$key]}" | sed 's/^/  /'
            echo ""
        done
        echo '}'
    } > "$output_file"

    log "NixOS module written to: $output_file"
}

# Description: Drop all registered nixcfg blocks and the cached header.
nds_nixcfg_clear() {
    NDS_NIXCFG_BLOCKS=()
    NDS_NIXCFG_HEADER=""
    debug "Cleared all NixOS config blocks"
}
