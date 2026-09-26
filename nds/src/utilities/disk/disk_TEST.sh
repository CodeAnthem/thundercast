#!/usr/bin/env bash
# ==================================================================================================
# disk utility - selfchecks (bashTestSuite)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")" --depth 0

suite_disk_utility() {
    local out secrets_dir pw_file

    if ! declare -f disk_part &>/dev/null; then
        nds_requireUtility disk || {
            bts_fail "disk utility not loadable"
            return 0
        }
    fi

    _disk_util_ok() { bts_pass "$1"; }
    _disk_util_fail() { bts_fail "$1"; }
    _disk_util_assert() {
        local name="$1"; shift
        if "$@"; then _disk_util_ok "$name"; else _disk_util_fail "$name"; fi
    }
    _disk_util_assert_eq() {
        local name="$1" got="$2" want="$3"
        if [[ "$got" == "$want" ]]; then _disk_util_ok "$name"
        else _disk_util_fail "$name ($got != $want)"; fi
    }

    out=${ disk_part "/dev/nvme0n1" 2; }
    _disk_util_assert_eq "part nvme" "$out" "/dev/nvme0n1p2"
    out=${ disk_part "/dev/sda" 2; }
    _disk_util_assert_eq "part sd" "$out" "/dev/sda2"
    out=${ disk_part "/dev/mmcblk0" 1; }
    _disk_util_assert_eq "part mmcblk" "$out" "/dev/mmcblk0p1"

    out=${ disk_urandomChars 16; }
    if [[ ${#out} -eq 16 && "$out" =~ ^[A-Za-z0-9]+$ ]]; then
        _disk_util_ok "urandom length/charset"
    else
        _disk_util_fail "urandom length/charset"
    fi

    _disk_util_assert_false() {
        local name="$1"; shift
        if "$@"; then _disk_util_fail "$name"; else _disk_util_ok "$name"; fi
    }
    _disk_util_assert_false "canUse empty" disk_canUse ""
    _disk_util_assert_false "canUse missing" disk_canUse "/dev/nds_disk_util_missing_$$"

    out=${ disk_probeState "" || true; }
    _disk_util_assert_eq "probe empty → wiped" "$out" "wiped"

    local _disk_log=()
    cryptsetup() { _disk_log+=("$*"); }
    mkfs.ext4() { _disk_log+=("mkfs $*"); return 0; }
    wipefs() { return 0; }
    if disk_luksFormat /dev/vda2 /tmp/pass.txt /tmp/key.bin; then
        if [[ "${_disk_log[*]}" == *'--key-file /tmp/pass.txt'* && "${_disk_log[*]}" == *'/tmp/key.bin'* ]]; then
            _disk_util_ok "luksFormat passes the secret files through"
        else
            _disk_util_fail "luksFormat args were '${_disk_log[*]}'"
        fi
    else
        _disk_util_fail "luksFormat returned failure"
    fi

    out=${ _disk_diskoTemplate; }
    if [[ -f "$out" ]]; then
        _disk_util_ok "disko template present"
    else
        _disk_util_fail "disko template present ($out)"
    fi
    if [[ -f "$out" ]] && ! grep -Eq '^[[:space:]]*\{[[:space:]]*(config|pkgs),' "$out"; then
        _disk_util_ok "disko template attrset"
    elif [[ -f "$out" ]]; then
        _disk_util_fail "disko template has module args"
    fi
    if [[ -f "$out" ]] && grep -q 'espAtBoot = bootLoader != "grub"' "$out" \
        && grep -q 'mkFsMnt "vfat" "/boot"' "$out"; then
        _disk_util_ok "disko ESP at /boot"
    elif [[ -f "$out" ]]; then
        _disk_util_fail "disko ESP at /boot"
    fi
    if [[ -f "$out" ]] && grep -q -- '-n" "boot"' "$out" \
        && grep -q -- '-L" "nixos"' "$out"; then
        _disk_util_ok "disko labels boot/nixos"
    elif [[ -f "$out" ]]; then
        _disk_util_fail "disko labels boot/nixos"
    fi
    if [[ -f "$out" ]] && command -v nix-instantiate >/dev/null 2>&1 \
        && declare -f _disk_diskoGenerateParams &>/dev/null; then
        local disko_work eval_out
        disko_work=$(mktemp -d)
        cp "$out" "${disko_work}/default.nix"
        _disk_diskoGenerateParams \
            "${disko_work}/params.nix" "/dev/sda" "ext4" "0" "false" "20G" "false" "manual"
        eval_out=$(nix-instantiate --eval --expr \
            "builtins.isAttrs (import ${disko_work}/default.nix)" 2>/dev/null || true)
        if [[ "$eval_out" == "true" ]]; then
            _disk_util_ok "disko imports without pkgs"
        else
            _disk_util_fail "disko imports without pkgs"
        fi
        rm -rf "$disko_work"
    fi

    out=${ disk_efiLoaderPath grub; }
    _disk_util_assert_eq "efi path grub" "$out" '\\EFI\\nixos\\grubx64.efi'
    out=${ disk_efiLoaderPath systemd-boot; }
    _disk_util_assert_eq "efi path systemd-boot" "$out" '\\EFI\\systemd\\systemd-bootx64.efi'
    _disk_util_assert_false "bios_grub empty" disk_hasBiosGrub ""
    _disk_util_assert_false "bios_grub missing" disk_hasBiosGrub "/dev/nds_disk_util_missing_$$"

    return 0
}
