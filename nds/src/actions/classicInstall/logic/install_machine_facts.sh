#!/usr/bin/env bash
# ==================================================================================================
# NDS - Machine facts writer
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-27 | Modified: 2026-08-16
# Description:   Write per-host mounts.nix (committed) — root/boot UUID mounts + optional LUKS
# ==================================================================================================

# Description: Resolve blkid UUID for a device node.
# Arguments:
# - device: <String> Block device path
# Returns:
# - <String> UUID (stdout)
_nds_install_blkid_uuid() {
    local device="$1"
    blkid -s UUID -o value "$device" 2>/dev/null || true
}

# Description: Device currently mounted at a path (e.g. /mnt or /mnt/boot).
# Arguments:
# - mountpoint: <String> Mount path
# Returns:
# - <String> source device (stdout)
_nds_install_findmnt_source() {
    local mountpoint="$1"
    findmnt -n -o SOURCE --target "$mountpoint" 2>/dev/null || true
}

# Find LUKS partition UUID (works for nds, disko, and nvme layouts).
# Usage: _nds_install_find_luks_uuid ["disk"]
_nds_install_find_luks_uuid() {
    local disk="${1:-}"
    local part uuid backing

    if [[ -e /dev/mapper/cryptroot ]]; then
        backing=$(cryptsetup status cryptroot 2>/dev/null | awk '/device:/ {print $2}')
        if [[ -n "$backing" ]]; then
            uuid=$(blkid -s UUID -o value "$backing" 2>/dev/null || true)
            if [[ -n "$uuid" ]]; then
                echo "$uuid"
                return 0
            fi
        fi
    fi

    if [[ -n "$disk" ]]; then
        for part in "${disk}"*; do
            [[ -b "$part" ]] || continue
            [[ "$(blkid -s TYPE -o value "$part" 2>/dev/null)" == "crypto_LUKS" ]] || continue
            uuid=$(blkid -s UUID -o value "$part" 2>/dev/null || true)
            if [[ -n "$uuid" ]]; then
                echo "$uuid"
                return 0
            fi
        done

        nds_requireUtility disk || return 1
        part=${ disk_part "$disk" 2; }
        uuid=$(blkid -s UUID -o value "$part" 2>/dev/null || true)
        if [[ -n "$uuid" ]]; then
            echo "$uuid"
            return 0
        fi
    fi

    return 1
}

# Description: Write mounts.nix with by-uuid root/boot mounts (and LUKS when encrypted).
# Always rewrite, including committed by-label placeholders from flake eval.
# Prefer UUID over filesystem labels — VMware hard resets often race by-label in initrd,
# and Disko may not set the boot/nixos labels the scaffold assumes.
# Usage: _nds_install_write_mounts_nix "disk" "hostname" "flake_root" "encryption" ["host_dir_rel"] [dest]
_nds_install_write_mounts_nix() {
    local disk="$1"
    local hostname="$2"
    local flake_root="$3"
    local use_encryption="${4:-false}"
    local host_dir_rel="${5:-hosts/x86_64-linux}"
    local dest="${6:-}"
    local host_dir root_dev boot_dev root_uuid boot_uuid luks_uuid=""
    local root_fs=ext4 boot_fs=vfat
    local esp_dev="" esp_uuid="" esp_fs=""

    if [[ -z "$flake_root" || ! -d "$flake_root" ]]; then
        warn "Flake root not set or missing — skip mounts.nix (set NDS_FLAKE_ROOT)"
        return 0
    fi

    host_dir="${flake_root}/${host_dir_rel}/${hostname}"
    mkdir -p "$host_dir" "$(dirname "${dest:-$host_dir}")"
    [[ -n "$dest" ]] || dest="${host_dir}/nds_generated.nix"

    root_dev="$(_nds_install_findmnt_source /mnt)"
    boot_dev="$(_nds_install_findmnt_source /mnt/boot)"

    if [[ -z "$root_dev" ]]; then
        if [[ "$use_encryption" == "true" ]]; then
            root_dev="/dev/mapper/cryptroot"
        else
            root_dev="/dev/disk/by-label/nixos"
        fi
    fi
    [[ -n "$boot_dev" ]] || boot_dev="/dev/disk/by-label/boot"

    # Resolve to underlying block UUID when findmnt returns a mapper or path
    if [[ -e /dev/mapper/cryptroot && "$root_dev" == /dev/mapper/cryptroot ]]; then
        root_uuid="$(_nds_install_blkid_uuid /dev/mapper/cryptroot)"
        root_fs=$(blkid -s TYPE -o value /dev/mapper/cryptroot 2>/dev/null || echo ext4)
    else
        root_uuid="$(_nds_install_blkid_uuid "$root_dev")"
        root_fs=$(blkid -s TYPE -o value "$root_dev" 2>/dev/null || echo ext4)
    fi
    boot_uuid="$(_nds_install_blkid_uuid "$boot_dev")"
    boot_fs=$(blkid -s TYPE -o value "$boot_dev" 2>/dev/null || echo vfat)
    esp_dev="$(_nds_install_findmnt_source /mnt/boot/efi)"

    if [[ -z "$root_uuid" ]]; then
        error "Could not determine root UUID (source=${root_dev}) — refuse by-label root"
        return 1
    fi
    if [[ -z "$boot_uuid" ]]; then
        error "Could not determine boot UUID (source=${boot_dev})"
        return 1
    fi

    if [[ "$use_encryption" == "true" ]]; then
        if ! luks_uuid=$(_nds_install_find_luks_uuid "$disk"); then
            error "Could not determine LUKS UUID (disk=${disk})"
            return 1
        fi
    fi

    {
        printf '%s\n' \
            '# ==================================================================================================' \
            "# NDS - ${hostname}" \
            '# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::' \
            "# Date:          Created: $(date -u +%Y-%m-%d) | Modified: $(date -u +%Y-%m-%d)" \
            '# Description:   NDS install-time mounts (by-uuid)' \
            '# ==================================================================================================' \
            '' \
            '{ ... }: {' \
            "  fileSystems.\"/\" = {" \
            "    device = \"/dev/disk/by-uuid/${root_uuid}\";" \
            "    fsType = \"${root_fs}\";" \
            '  };' \
            "  fileSystems.\"/boot\" = {" \
            "    device = \"/dev/disk/by-uuid/${boot_uuid}\";" \
            "    fsType = \"${boot_fs}\";" \
            "    neededForBoot = true;" \
            "    options = [ \"fmask=0077\" \"dmask=0077\" ];" \
            '  };'
        if [[ -n "$esp_dev" && "$esp_dev" != "$boot_dev" ]]; then
            esp_uuid="$(_nds_install_blkid_uuid "$esp_dev")"
            esp_fs=$(blkid -s TYPE -o value "$esp_dev" 2>/dev/null || echo vfat)
            if [[ -n "$esp_uuid" ]]; then
                printf '%s\n' \
                    "  fileSystems.\"/boot/efi\" = {" \
                    "    device = \"/dev/disk/by-uuid/${esp_uuid}\";" \
                    "    fsType = \"${esp_fs}\";" \
                    "    neededForBoot = true;" \
                    "    options = [ \"fmask=0077\" \"dmask=0077\" ];" \
                    '  };'
            fi
        fi
        if [[ -n "$luks_uuid" ]]; then
            printf '  opts.nixos.security.luks.device = "/dev/disk/by-uuid/%s";\n' "$luks_uuid"
        fi
        printf '%s\n' '}'
    } >"$dest"

    log "Wrote mounts for ${hostname} (root UUID ${root_uuid}, boot UUID ${boot_uuid})"
    nds_install_log "mounts written for ${hostname} (by-uuid)"
    return 0
}
