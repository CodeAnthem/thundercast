#!/usr/bin/env bash
# ==================================================================================================
# NDS - Loop-device disk tier
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-27 | Modified: 2026-09-27
# Description:   Opt-in. Real sgdisk/cryptsetup/mkfs/mount against a file-backed loop device.
#                Not part of selftest. Needs passwordless sudo.
# ==================================================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

_loop_hint() {
    printf '%s\n' "apt install gdisk cryptsetup-bin dosfstools parted" >&2
    printf '%s\n' "On WSL, sudo modprobe loop may be needed first." >&2
}

if ! sudo -n true 2>/dev/null; then
    printf '%s\n' "looptest: sudo -n true failed" >&2
    _loop_hint
    exit 2
fi

_loop_missing=()
for _loop_bin in losetup sgdisk cryptsetup mkfs.ext4 mkfs.vfat mkfs.fat parted; do
    command -v "$_loop_bin" >/dev/null 2>&1 || _loop_missing+=("$_loop_bin")
done
if ((${#_loop_missing[@]})); then
    printf '%s\n' "looptest: missing ${_loop_missing[*]}" >&2
    _loop_hint
    exit 2
fi

img="${NDS_LOOP_IMG_DIR:-/dev/shm}/nds-loop.img"
dev=""

_loop_cleanup() {
    local _loop_src _loop_mnt
    if [[ -n "$dev" ]]; then
        while read -r _loop_src _loop_mnt; do
            [[ "$_loop_src" == "$dev"* ]] || continue
            sudo umount -R "$_loop_mnt" 2>/dev/null || true
        done < <(findmnt -rn -o SOURCE,TARGET 2>/dev/null || true)
        sudo cryptsetup close cryptroot 2>/dev/null || true
        sudo losetup -d "$dev" 2>/dev/null || true
    fi
    rm -f "$img"
}
trap _loop_cleanup EXIT

mkdir -p "$(dirname "$img")"
truncate -s "${NDS_LOOP_SIZE:-4G}" "$img"
if ! dev=$(sudo losetup -fP --show "$img"); then
    sudo modprobe loop 2>/dev/null || true
    if ! dev=$(sudo losetup -fP --show "$img"); then
        printf '%s\n' "looptest: losetup failed for ${img}" >&2
        _loop_hint
        exit 2
    fi
fi
export NDS_LOOP_DEV="$dev"
bash "$ROOT/utilities/bashTestSuite/main.sh" "$ROOT/nds/src/utilities/disk/disk_LOOP_TEST.sh"
