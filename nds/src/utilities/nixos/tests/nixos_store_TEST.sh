#!/usr/bin/env bash
# ==================================================================================================
# nixos utility - install store / NIX_CONFIG units
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-03 | Modified: 2026-09-03
# ==================================================================================================

suite_nixos_store() {
    local out base="experimental-features = nix-command flakes"
    local root

    _ns_ok() {
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nixos_store: $1"
    }
    _ns_fail() {
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nixos_store: $1"
    }

    if ! declare -f _nds_install_nix_combined_nix_config &>/dev/null; then
        _ns_fail "combined_nix_config missing"
        return 0
    fi

    local _restore_free _restore_ready
    _restore_free=$(declare -f _nds_install_nix_store_free_mb)
    _restore_ready=$(declare -f _nds_install_nix_ensure_store_ready)

    # Large live store → no chroot override (ISO store stays default).
    _nds_install_nix_store_free_mb() { echo 8192; }
    out=${ _nds_install_nix_combined_nix_config "$base"; }
    if [[ "$out" == "$base" ]]; then
        _ns_ok "no store line when live store is large"
    else
        _ns_fail "unexpected store override while live store large"
    fi

    # Small store + forced mounted target → append store = <root>.
    root=$(mktemp -d "${TMPDIR:-/tmp}/nds_nix_root.XXXXXX")
    NDS_NIX_TARGET_ROOT="$root"
    NDS_NIX_INSTALL_STORE_FORCE=1
    _nds_install_nix_store_free_mb() { echo 100; }
    _nds_install_nix_ensure_store_ready() { return 0; }
    out=${ _nds_install_nix_combined_nix_config "$base"; }
    if [[ "$out" == *$'\n'"store = ${root}"* ]] || [[ "$out" == *"store = ${root}"* ]]; then
        _ns_ok "chroot store line when target forced + low free"
    else
        _ns_fail "missing store = ${root} in combined config"
    fi

    eval "$_restore_free"
    eval "$_restore_ready"
    unset NDS_NIX_TARGET_ROOT NDS_NIX_INSTALL_STORE_FORCE
    rm -rf "$root"
}
