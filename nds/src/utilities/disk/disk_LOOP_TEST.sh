#!/usr/bin/env bash
# ==================================================================================================
# disk utility - loop device tier
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-27 | Modified: 2026-09-27
# Description:   Real parted, cryptsetup, mkfs, and mount. Skipped unless NDS_LOOP_DEV is set.
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
logger_setMinLevel error
import_dir "$(dirname "${BASH_SOURCE[0]}")" --depth 0
import_dir "$(dirname "${BASH_SOURCE[0]}")/../targetSeed" --depth 0

_loop_pass=""

_loop_luks() {
    disk_luksFormat "$1" "$_loop_pass" ""
}

suite_disk_loop() {
    [[ -n ${NDS_LOOP_DEV:-} ]] || { bts_pass "loop tier not requested"; return 0; }
    local dev root part layout seed mode key
    dev=$NDS_LOOP_DEV
    if [[ "$dev" != /dev/loop* ]]; then
        bts_fail "NDS_LOOP_DEV must be a loop device, was '${dev}'"
        return 0
    fi
    nds_test_stubBins nixos-install efibootmgr nixos-generate-config
    root=$(mktemp -d)
    _NDS_TARGET_ROOT=$root
    _loop_pass=$(mktemp)
    printf '%s\n' 'loop-passphrase-for-the-tier' > "$_loop_pass"
    chmod 600 "$_loop_pass"

    if ! disk_partition "$dev" false "" >/dev/null 2>/dev/null; then
        bts_fail "unencrypted disk_partition failed"
        return 0
    fi
    layout=$(lsblk -no FSTYPE,LABEL "$dev")
    if [[ "$layout" == *vfat* && "$layout" == *boot* && "$layout" == *ext4* && "$layout" == *nixos* ]]; then
        bts_pass "lsblk shows the fat boot partition and the ext4 root"
    else
        bts_fail "layout was '${layout}'"
        return 0
    fi

    if disk_mountRoot false "$root" >/dev/null 2>/dev/null \
        && mountpoint -q "$root" && mountpoint -q "${root}/boot"; then
        bts_pass "disk_mountRoot false mounts the root and boot under the target root"
    else
        bts_fail "unencrypted mount failed"
        return 0
    fi
    disk_unmountTarget "$root" >/dev/null 2>/dev/null || true

    if ! disk_partition "$dev" true true _loop_luks >/dev/null 2>/dev/null; then
        bts_fail "encrypted disk_partition failed"
        return 0
    fi
    part=$(disk_part "$dev" 2)
    if cryptsetup isLuks "$part"; then
        bts_pass "the root partition is LUKS"
    else
        bts_fail "cryptsetup isLuks failed for ${part}"
        return 0
    fi
    if disk_mountRoot true "$root" >/dev/null 2>/dev/null && mountpoint -q "$root"; then
        bts_pass "disk_mountRoot true opens and mounts the encrypted root"
    else
        bts_fail "encrypted mount failed"
        return 0
    fi

    key=$(mktemp)
    printf '%s\n' 'initrd-host-key' > "$key"
    if disk_setupInitrdSshKeys "$root" "$key" \
        && [[ $(<"${root}/etc/secrets/initrd/ssh_host_ed25519_key") == 'initrd-host-key' ]]; then
        bts_pass "disk_setupInitrdSshKeys places the host key on the mount"
    else
        bts_fail "initrd host key was not placed"
        return 0
    fi

    seed=$(mktemp -d)
    printf '%s\n' seed > "${seed}/marker"
    chmod 640 "${seed}/marker"
    targetSeed_copy "$seed" "$root"
    mode=$(stat -c '%a' "${root}/marker")
    if [[ "$mode" == 640 && $(<"${root}/marker") == seed ]]; then
        bts_pass "targetSeed_copy preserves the file mode"
    else
        bts_fail "copied mode was ${mode}"
        return 0
    fi

    disk_unmountTarget "$root" >/dev/null 2>/dev/null
    if ! mountpoint -q "$root" && ! findmnt -rn -S "${dev}" >/dev/null; then
        bts_pass "disk_unmountTarget leaves nothing mounted"
    else
        bts_fail "a filesystem is still mounted"
    fi

    nds_test_stubBins_drop
    rm -rf "$root" "$seed" "$key" "$_loop_pass"
}
