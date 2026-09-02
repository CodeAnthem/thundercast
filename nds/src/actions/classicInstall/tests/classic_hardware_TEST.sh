#!/usr/bin/env bash
# ==================================================================================================
# classicInstall - hardware / boot naming units
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-03 | Modified: 2026-09-03
# ==================================================================================================

suite_classic_hardware() {
    local out

    _ch_ok() {
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ classic_hw: $1"
    }
    _ch_fail() {
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ classic_hw: $1"
    }
    _ch_eq() {
        local name="$1" got="$2" want="$3"
        if [[ "$got" == "$want" ]]; then _ch_ok "$name"
        else _ch_fail "$name ($got != $want)"; fi
    }

    if ! declare -f _nds_install_hardware_artifact_name &>/dev/null; then
        _ch_fail "hardware_artifact_name missing"
        return 0
    fi

    NDS_CURRENT_ACTION=classicInstall
    unset NDS_HARDWARE_GEN
    out=${ _nds_install_hardware_artifact_name; }
    _ch_eq "classic → hardware-configuration.nix" "$out" "hardware-configuration.nix"

    NDS_CURRENT_ACTION=installFlake
    unset NDS_HARDWARE_GEN
    out=${ _nds_install_hardware_artifact_name; }
    _ch_eq "flake default → facter.json" "$out" "facter.json"

    NDS_HARDWARE_GEN=legacy
    out=${ _nds_install_hardware_artifact_name; }
    _ch_eq "flake legacy → hardware-configuration.nix" "$out" "hardware-configuration.nix"

    NDS_CURRENT_ACTION=remoteAction
    unset NDS_HARDWARE_GEN
    out=${ _nds_install_hardware_artifact_name; }
    _ch_eq "remoteAction → facter.json" "$out" "facter.json"
    unset NDS_CURRENT_ACTION NDS_HARDWARE_GEN

    if declare -f _nds_install_efi_loader_path &>/dev/null; then
        nds_cfg_set BOOT_LOADER grub
        out=${ _nds_install_efi_loader_path; }
        _ch_eq "efi path grub" "$out" '\\EFI\\nixos\\grubx64.efi'
        nds_cfg_set BOOT_LOADER systemd-boot
        out=${ _nds_install_efi_loader_path; }
        _ch_eq "efi path systemd-boot" "$out" '\\EFI\\systemd\\systemd-bootx64.efi'
    else
        _ch_fail "efi_loader_path missing"
    fi

    if declare -f _nds_install_disk_has_bios_grub &>/dev/null; then
        if _nds_install_disk_has_bios_grub "" || _nds_install_disk_has_bios_grub "/dev/nds_no_such_disk_$$"; then
            _ch_fail "bios_grub rejects empty/missing disk"
        else
            _ch_ok "bios_grub rejects empty/missing disk"
        fi
    fi
}
