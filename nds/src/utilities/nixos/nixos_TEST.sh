# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")" --depth 0

#!/usr/bin/env bash
# ==================================================================================================
# nixos utility - install store / NIX_CONFIG units
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-03 | Modified: 2026-09-03
# ==================================================================================================

suite_nixos_store() {
    local out base="experimental-features = nix-command flakes"
    local root

    _ns_ok() { bts_pass "$1"; }
    _ns_fail() { bts_fail "$1"; }

    if ! declare -f nixos_combinedNixConfig &>/dev/null; then
        _ns_fail "combined_nix_config missing"
        return 0
    fi

    local _restore_free _restore_ready
    _restore_free=$(declare -f nixos_storeFreeMb)
    _restore_ready=$(declare -f nixos_ensureStoreReady)

    # Large live store → no chroot override (ISO store stays default).
    nixos_storeFreeMb() { echo 8192; }
    out=${ nixos_combinedNixConfig "$base"; }
    if [[ "$out" == "$base" ]]; then
        _ns_ok "no store line when live store is large"
    else
        _ns_fail "unexpected store override while live store large"
    fi

    # Small store + forced mounted target → append store = <root>.
    root=$(mktemp -d "${TMPDIR:-/tmp}/nds_nix_root.XXXXXX")
    NDS_NIX_TARGET_ROOT="$root"
    NDS_NIX_INSTALL_STORE_FORCE=1
    nixos_storeFreeMb() { echo 100; }
    nixos_ensureStoreReady() { return 0; }
    out=${ nixos_combinedNixConfig "$base"; }
    if [[ "$out" == *$'\n'"store = ${root}"* ]] || [[ "$out" == *"store = ${root}"* ]]; then
        _ns_ok "chroot store line when target forced + low free"
    else
        _ns_fail "missing store = ${root} in combined config"
    fi

    eval "$_restore_free"
    eval "$_restore_ready"
    unset NDS_NIX_TARGET_ROOT NDS_NIX_INSTALL_STORE_FORCE
    rm -rf "$root"

    nds_test_stubBins nixos-install
    root=$(mktemp -d)
    local src
    src=$(mktemp -d)
    mkdir -p "${root}/etc/nixos" "$src"
    printf '%s\n' '{ }' > "${src}/configuration.nix"
    if nixos_copyConfigs "$src" "$root" >/dev/null 2>/dev/null \
        && nixos_installClassic "$root" >/dev/null 2>/dev/null \
        && grep -q "nixos-install --root ${root} --no-root-passwd" "$NDS_TEST_BIN_LOG"; then
        _ns_ok "nixos_installClassic passes the mount root"
    else
        _ns_fail "nixos-install log was '$(<"$NDS_TEST_BIN_LOG")'"
    fi
    nds_test_stubBins_drop
    rm -rf "$root" "$src"
}
