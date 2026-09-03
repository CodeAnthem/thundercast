#!/usr/bin/env bash
# ==================================================================================================
# nixcfg - install-time mounts module (by-uuid root/boot, optional LUKS device)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-27 | Modified: 2026-09-03
# Description:   Prefer UUID over labels — by-label races in initrd on hard resets; disko may not
#                set the labels the scaffold assumes.
# ==================================================================================================

# Description: Write a `{ ... }: { fileSystems… }` module from the mounted target.
# Arguments:
# - dest:           <String> Output file
# - hostname:       <String> Host name (header only)
# - disk:           <String> Target disk (LUKS UUID scan fallback)
# - use_encryption: <String> true | false
# - root:           <String|optional> Mounted target root (default /mnt)
# Returns:
# - <Bool> 0 on success
nds_nixcfg_write_mounts_module() {
    local dest="$1"
    local hostname="$2"
    local disk="$3"
    local use_encryption="${4:-false}"
    local root="${5:-/mnt}"
    local root_dev boot_dev root_uuid boot_uuid luks_uuid=""
    local root_fs boot_fs esp_dev="" esp_uuid="" esp_fs=""

    nds_requireUtility disk || return 1
    mkdir -p "$(dirname "$dest")"

    root_dev="$(disk_findmntSource "$root")"
    boot_dev="$(disk_findmntSource "${root}/boot")"
    if [[ -z "$root_dev" ]]; then
        if [[ "$use_encryption" == "true" ]]; then
            root_dev="/dev/mapper/cryptroot"
        else
            root_dev="/dev/disk/by-label/nixos"
        fi
    fi
    [[ -n "$boot_dev" ]] || boot_dev="/dev/disk/by-label/boot"

    root_uuid="$(disk_blkidUuid "$root_dev")"
    root_fs="$(disk_blkidType "$root_dev" ext4)"
    boot_uuid="$(disk_blkidUuid "$boot_dev")"
    boot_fs="$(disk_blkidType "$boot_dev" vfat)"
    esp_dev="$(disk_findmntSource "${root}/boot/efi")"

    [[ -n "$root_uuid" ]] || { error "Could not determine root UUID (source=${root_dev}) — refuse by-label root"; return 1; }
    [[ -n "$boot_uuid" ]] || { error "Could not determine boot UUID (source=${boot_dev})"; return 1; }
    if [[ "$use_encryption" == "true" ]]; then
        luks_uuid=$(disk_findLuksUuid "$disk") || { error "Could not determine LUKS UUID (disk=${disk})"; return 1; }
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
            esp_uuid="$(disk_blkidUuid "$esp_dev")"
            esp_fs="$(disk_blkidType "$esp_dev" vfat)"
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
    } >"$dest" || return 1

    nds_install_log "mounts written for ${hostname} (root UUID ${root_uuid}, boot UUID ${boot_uuid})"
    return 0
}
