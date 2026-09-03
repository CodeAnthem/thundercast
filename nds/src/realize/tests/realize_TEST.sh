#!/usr/bin/env bash
# ==================================================================================================
# realize - kind/mode resolution, plan wiring, argument-only utility contracts
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-03 | Modified: 2026-09-03
# ==================================================================================================

suite_realize() {
    local out f

    _rz_ok() {
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ realize: $1"
    }
    _rz_fail() {
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ realize: $1"
    }
    _rz_eq() {
        local name="$1" got="$2" want="$3"
        if [[ "$got" == "$want" ]]; then _rz_ok "$name"; else _rz_fail "$name ($got != $want)"; fi
    }

    for f in nds_realize_run nds_realize_confirm nds_realize_kind nds_realize_verify \
        _nds_realize_plan_classic _nds_realize_plan_flake_local _nds_realize_plan_flake_remote \
        nds_realize_preflight_local nds_realize_preflight_remote nds_realize_diag_step_failure; do
        declare -f "$f" &>/dev/null || { _rz_fail "missing $f"; return 0; }
    done
    _rz_ok "engine entry points present"

    nds_cfg_set INSTALL_KIND ""
    nds_cfg_set FLAKE_HOST ""
    nds_cfg_set FLAKE_REPO_URL ""
    nds_cfg_set FLAKE_LOCAL_PATH ""
    _rz_eq "kind defaults to classic" "${ nds_realize_kind; }" "classic"
    nds_cfg_set FLAKE_REPO_URL "git@github.com:acme/leaf.git"
    _rz_eq "kind infers flake from FLAKE_REPO_URL" "${ nds_realize_kind; }" "flake"
    nds_cfg_set INSTALL_KIND classic
    _rz_eq "explicit INSTALL_KIND wins" "${ nds_realize_kind; }" "classic"
    nds_cfg_set INSTALL_KIND ""

    _rz_eq "flake source remote when URL set" "${ _nds_realize_flake_source; }" "remote"
    nds_cfg_set FLAKE_REPO_URL ""
    nds_cfg_set FLAKE_LOCAL_PATH "/tmp/leaf"
    _rz_eq "flake source local when path set" "${ _nds_realize_flake_source; }" "local"
    nds_cfg_set FLAKE_LOCAL_PATH ""

    nds_cfg_set NETWORK_HOSTNAME "node-a"
    nds_cfg_set FLAKE_HOST ""
    _rz_eq "flake host falls back to NETWORK_HOSTNAME" "${ _nds_realize_flake_host; }" "node-a"
    nds_cfg_set NETWORK_HOSTNAME ""

    nds_cfg_set INSTALL_MODE ""
    _rz_eq "mode defaults to local" "${ nds_realize_mode; }" "local"

    nds_cfg_set INSTALL_KIND classic
    _rz_eq "classic artifact" "${ _nds_realize_hw_artifact_name; }" "hardware-configuration.nix"
    nds_cfg_set INSTALL_KIND flake
    unset NDS_HARDWARE_GEN
    _rz_eq "flake artifact (facter)" "${ _nds_realize_hw_artifact_name; }" "facter.json"
    NDS_HARDWARE_GEN=legacy
    _rz_eq "flake artifact (legacy)" "${ _nds_realize_hw_artifact_name; }" "hardware-configuration.nix"
    unset NDS_HARDWARE_GEN
    nds_cfg_set INSTALL_KIND ""

    if _nds_realize_is_uefi true && ! _nds_realize_is_uefi false; then
        _rz_ok "uefi decision honours BOOT_UEFI_MODE"
    else
        _rz_fail "uefi decision ignores BOOT_UEFI_MODE"
    fi

    if nds_realize_preflight_local "/dev/nds_no_such_disk_$$" "" grub 2>/dev/null; then
        _rz_fail "preflight accepts missing disk"
    else
        _rz_ok "preflight rejects missing disk"
    fi
    if nds_realize_preflight_local "" false systemd-boot 2>/dev/null; then
        _rz_fail "preflight accepts systemd-boot on BIOS"
    else
        _rz_ok "preflight rejects systemd-boot on BIOS"
    fi

    # Plans must not reach for settings through env mirrors or a ctx snapshot.
    if rg -q 'NDS_CTX_|NDS_FLAKE_(SOURCE|REPO_URL|LOCAL_PATH|INSTALL_PATH|HOST_DIR|HOST)\b|NDS_HARDWARE_PLACEMENT|NDS_INSTALL_MODE|NDS_REMOTE_TARGET_IP|NDS_DISK_STRATEGY' \
        "${SCRIPT_DIR}/realize" --glob '*.sh' --glob '!**/tests/**' 2>/dev/null; then
        _rz_fail "realize reads env mirrors / ctx snapshot"
    else
        _rz_ok "realize reads settings only (nds_cfg_get) — no env mirrors"
    fi
}
