#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-08-16
# Description:   NixOS Config Generation - Boot Module
# Feature:       Bootloader configuration (systemd-boot, GRUB, rEFInd)
# ==================================================================================================

# =============================================================================
# NIXOS CONFIG GENERATION - Public API
# =============================================================================

# Manual mode: explicit parameters
nds_nixcfg_boot() {
    local bootloader="$1"
    local uefi="${2:-true}"
    local disk="${3:-}"

    _nds_nixcfg_boot_generate "$bootloader" "$uefi" "$disk"
}

# =============================================================================
# NIXOS CONFIG GENERATION - Implementation
# =============================================================================

_nds_nixcfg_boot_generate() {
    local bootloader="$1"
    local uefi="$2"
    local disk="${3:-}"

    if [[ "$uefi" != "true" && "$bootloader" == "systemd-boot" ]]; then
        warn "systemd-boot requires UEFI — generating GRUB for BIOS boot"
        bootloader=grub
    elif [[ "$uefi" != "true" && "$bootloader" == "refind" ]]; then
        warn "rEFInd requires UEFI — generating GRUB for BIOS boot"
        bootloader=grub
    fi

    case "$bootloader" in
        systemd-boot)
            _nds_nixcfg_boot_systemd "$uefi"
            ;;
        grub)
            _nds_nixcfg_boot_grub "$uefi" false "$disk"
            ;;
        refind)
            _nds_nixcfg_boot_refind "$uefi"
            ;;
        *)
            error "Unknown bootloader: $bootloader"
            return 1
            ;;
    esac
}

_nds_nixcfg_boot_generate_flake() {
    local bootloader="$1"
    local uefi="$2"
    local disk="${3:-}"

    if [[ "$uefi" != "true" && "$bootloader" == "systemd-boot" ]]; then
        warn "systemd-boot requires UEFI — generating GRUB for BIOS boot"
        bootloader=grub
    elif [[ "$uefi" != "true" && "$bootloader" == "refind" ]]; then
        warn "rEFInd requires UEFI — generating GRUB for BIOS boot"
        bootloader=grub
    fi

    case "$bootloader" in
        systemd-boot)
            _nds_nixcfg_boot_systemd_flake "$uefi"
            ;;
        grub)
            _nds_nixcfg_boot_grub "$uefi" true "$disk"
            ;;
        refind)
            _nds_nixcfg_boot_refind_flake "$uefi"
            ;;
        *)
            error "Unknown bootloader: $bootloader"
            return 1
            ;;
    esac
}

# Description: ESP mount used by bootctl (vfat). Prefer /boot/efi when that is the ESP.
# Returns:
# - <String> /boot or /boot/efi
_nds_nixcfg_efi_sys_mount_point() {
    local root="${NDS_NIX_TARGET_ROOT:-/mnt}"
    local fstype=""

    fstype=$(findmnt -n -o FSTYPE --target "${root}/boot/efi" 2>/dev/null || true)
    case "$fstype" in
        vfat|fat|fat32|msdos)
            printf '%s\n' /boot/efi
            return 0
            ;;
    esac
    fstype=$(findmnt -n -o FSTYPE --target "${root}/boot" 2>/dev/null || true)
    case "$fstype" in
        vfat|fat|fat32|msdos)
            printf '%s\n' /boot
            return 0
            ;;
    esac
    printf '%s\n' /boot
}

_nds_nixcfg_boot_systemd() {
    local uefi="$1"
    local esp

    if [[ "$uefi" != "true" ]]; then
        error "systemd-boot cannot be used without UEFI"
        return 1
    fi

    esp=${ _nds_nixcfg_efi_sys_mount_point; }
    local block
    block=$(nds_nixcfg_subst "$(cat <<'EOF'
boot.loader = {
  systemd-boot.enable = true;
  efi.canTouchEfiVariables = true;
  efi.efiSysMountPoint = "@@ESP@@";
};
EOF
)" @@ESP@@ "$esp")

    nds_nixcfg_register "boot" "$block" 10
}

_nds_nixcfg_boot_grub() {
    local uefi="$1"
    local use_force="${2:-false}"
    local disk="${3:-/dev/sda}"

    local block
    if [[ "$uefi" == "true" ]]; then
        if [[ "$use_force" == "true" ]]; then
            block=$(cat <<'EOF'
boot.loader = lib.mkForce {
  grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  efi.canTouchEfiVariables = false;
};
EOF
)
        else
            block=$(cat <<'EOF'
boot.loader = {
  grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = false;
  };
  efi.canTouchEfiVariables = true;
};
EOF
)
        fi
    else
        if [[ "$use_force" == "true" ]]; then
            block=$(nds_nixcfg_subst "$(cat <<'EOF'
boot.loader.grub = lib.mkForce {
  enable = true;
  device = "@@DISK@@";
};
EOF
)" @@DISK@@ "$disk")
        else
            block=$(nds_nixcfg_subst "$(cat <<'EOF'
boot.loader.grub = {
  enable = true;
  device = "@@DISK@@";
};
EOF
)" @@DISK@@ "$disk")
        fi
    fi

    nds_nixcfg_register "boot" "$block" 10
}

_nds_nixcfg_boot_systemd_flake() {
    local uefi="$1"
    local esp

    if [[ "$uefi" != "true" ]]; then
        error "systemd-boot cannot be used without UEFI"
        return 1
    fi

    esp=${ _nds_nixcfg_efi_sys_mount_point; }
    local block
    block=$(nds_nixcfg_subst "$(cat <<'EOF'
boot.loader = lib.mkForce {
  systemd-boot.enable = true;
  efi.canTouchEfiVariables = true;
  efi.efiSysMountPoint = "@@ESP@@";
};
EOF
)" @@ESP@@ "$esp")

    nds_nixcfg_register "boot" "$block" 10
}

_nds_nixcfg_boot_refind_flake() {
    local uefi="$1"

    if [[ "$uefi" != "true" ]]; then
        error "rEFInd cannot be used without UEFI"
        return 1
    fi

    local block
    block=$(cat <<'EOF'
boot.loader = lib.mkForce {
  refind.enable = true;
  efi.canTouchEfiVariables = true;
};
EOF
)

    nds_nixcfg_register "boot" "$block" 10
}

_nds_nixcfg_boot_refind() {
    local uefi="$1"

    if [[ "$uefi" != "true" ]]; then
        error "rEFInd cannot be used without UEFI"
        return 1
    fi

    local block
    block=$(cat <<'EOF'
boot.loader = {
  refind.enable = true;
  efi.canTouchEfiVariables = true;
};
EOF
)

    nds_nixcfg_register "boot" "$block" 10
}
