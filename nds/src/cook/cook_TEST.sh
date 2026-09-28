#!/usr/bin/env bash
# ==================================================================================================
# NDS - Cook plans
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../setup_TEST.sh
. "$(dirname "${BASH_SOURCE[0]}")/../setup_TEST.sh"
logger_setMinLevel warn
logger_scopeExists diagnose || logger_scopeCreate "Diagnose" diagnose
logger_scopeExists install || logger_scopeCreate "NixOS install" install nixosInstallation.log
logger_scopeExists session || logger_scopeCreate "NDS session" session
logger_scopeSet session
_gap=
_cook_load() { "import_${_gap}dir" "$@"; }
_cook_load "$(dirname "${BASH_SOURCE[0]}")/../recipe" --depth 0
_cook_load "$(dirname "${BASH_SOURCE[0]}")/../recipe/schema" --depth 0
nds_test_loadUtilities
_cook_load "$(dirname "${BASH_SOURCE[0]}")" --depth 0

_FIX="$(cd "$(dirname "${BASH_SOURCE[0]}")/../recipe/fixtures" && pwd)"

_cook_variant() {
    local src=$1 dest=$2
    shift 2
    declare -gA RECIPE=()
    nds_schema_enableAll
    nds_recipe_loadFile RECIPE "$src"
    nds_recipe_set RECIPE BOOT_LOADER grub
    nds_recipe_set RECIPE BOOT_UEFI_MODE false
    while (( $# )); do
        nds_recipe_set RECIPE "$1" "$2"
        shift 2
    done
    nds_recipe_seal RECIPE "$dest"
}

suite_cook() {
    local root pass flake out rc log hit
    nds_test_session
    nds_test_installBins
    export NDS_NIXOS_STATE_VERSION=26.05
    root=$_NDS_TARGET_ROOT
    pass="${ nds_session_dir secrets; }/admin.pass"
    printf '%s\n' 'admin-pass' > "$pass"
    chmod 600 "$pass"
    flake=$(mktemp -d)
    printf '%s\n' '{ outputs = { ... }: {}; }' > "${flake}/flake.nix"
    out=$(mktemp)

    bts_section "Plans"
    : >"$NDS_TEST_BIN_LOG"
    rc=0
    nds_cook "${_FIX}/incomplete.recipe" >/dev/null 2>/dev/null || rc=$? # validation
    if [[ "$rc" -eq 1 && ! -s "$NDS_TEST_BIN_LOG" ]]; then
        bts_pass "incomplete recipe returns 1 with no tool call"
    else
        bts_fail "incomplete rc was ${rc}"
    fi

    _cook_variant "${_FIX}/classic_min.recipe" "$out" \
        ACCESS_ADMIN_PASSWORD_FILE "$pass" ENCRYPTION false
    : >"$NDS_TEST_BIN_LOG"
    rc=0
    nds_cook "$out" >/dev/null 2>/dev/null || rc=$?
    log=$(<"$NDS_TEST_BIN_LOG")
    if [[ "$rc" -eq 0 && "$log" == *"parted /dev/stubdisk "* \
        && "$log" == *"mount /dev/disk/by-label/nixos ${root}"* \
        && "$log" == *"nixos-install --root ${root} "* \
        && "$log" != *'cryptsetup luksFormat'* ]]; then
        bts_pass "classic plan partitions, mounts, and runs nixos-install"
    else
        bts_fail "classic rc was ${rc} log '${log}'"
    fi

    _cook_variant "${_FIX}/classic_min.recipe" "$out" \
        ACCESS_ADMIN_PASSWORD_FILE "$pass" ENCRYPTION true ENCRYPTION_PASSWORD true \
        ENCRYPTION_PASSPHRASE_FILE "$pass" BOOT_UEFI_MODE false
    : >"$NDS_TEST_BIN_LOG"
    rc=0
    nds_cook "$out" >/dev/null 2>/dev/null || rc=$? # no /dev/mapper/cryptroot here
    log=$(<"$NDS_TEST_BIN_LOG")
    hit=$(printf '%s\n' "$log" | grep -n 'cryptsetup luksFormat' | head -1 | cut -d: -f1)
    if [[ -n "$hit" && "$log" == *"parted /dev/stubdisk "* \
        && "$log" == *"cryptsetup luksFormat --type luks2 /dev/stubdisk"* \
        && "$log" == *"nixos-install --root ${root} "* ]]; then
        bts_pass "encrypted classic runs cryptsetup luksFormat on the root partition"
    else
        bts_fail "encrypted log was '${log}'"
    fi

    _cook_variant "${_FIX}/flake_local.recipe" "$out" \
        FLAKE_LOCAL_PATH "$flake" FLAKE_INSTALL_PATH "${root}/etc/nixos" \
        ACCESS_ADMIN_PASSWORD_FILE "$pass" ENCRYPTION false
    : >"$NDS_TEST_BIN_LOG"
    rc=0
    nds_cook "$out" >/dev/null 2>/dev/null || rc=$?
    log=$(<"$NDS_TEST_BIN_LOG")
    if [[ "$rc" -eq 0 && "$log" == *"mountpoint -q ${root}"* && "$log" == *"nix build "* ]]; then
        bts_pass "flake local mounts the prepared root and builds the system"
    else
        bts_fail "flake local rc was ${rc} log '${log}'"
    fi

    bts_section "Leaf and seed"
    local leaf keys seed
    leaf=$(mktemp -d)
    keys=$(mktemp -d)
    _cook_variant "${_FIX}/flake_local.recipe" "$out" \
        FLAKE_LOCAL_PATH "$flake" FLAKE_INSTALL_PATH "${root}/etc/nixos" \
        ACCESS_ADMIN_PASSWORD_FILE "$pass" ENCRYPTION false \
        LEAF_PUSH_DIR "$leaf" LEAF_PUSH_MESSAGE 'add host' GIT_KEYS_DIR "$keys"
    : >"$NDS_TEST_BIN_LOG"
    rc=0
    nds_cook "$out" >/dev/null 2>/dev/null || rc=$?
    log=$(<"$NDS_TEST_BIN_LOG")
    if [[ "$rc" -eq 0 && "$log" == *"git -C ${leaf} commit "* \
        && "$log" == *"git -C ${leaf} push"* \
        && "$log" == *"mountpoint -q ${root}"* ]]; then
        bts_pass "a leaf push commits and pushes before the disk step"
    else
        bts_fail "leaf push rc was ${rc} log '${log}'"
    fi

    seed=$(mktemp -d)
    printf '%s\n' seed > "${seed}/marker"
    _cook_variant "${_FIX}/flake_local.recipe" "$out" \
        FLAKE_LOCAL_PATH "$flake" FLAKE_INSTALL_PATH "${root}/etc/nixos" \
        ACCESS_ADMIN_PASSWORD_FILE "$pass" ENCRYPTION false \
        TARGET_SEED_DIR "$seed"
    : >"$NDS_TEST_BIN_LOG"
    rc=0
    nds_cook "$out" >/dev/null 2>/dev/null || rc=$?
    if [[ "$rc" -eq 0 && $(<"${root}/marker") == seed ]]; then
        bts_pass "flake local with a seed copies it onto the target"
    else
        bts_fail "seed rc was ${rc}"
    fi

    _cook_variant "${_FIX}/flake_local.recipe" "$out" \
        FLAKE_LOCAL_PATH "$flake" FLAKE_INSTALL_PATH "${root}/etc/nixos" \
        ACCESS_ADMIN_PASSWORD_FILE "$pass" ENCRYPTION false \
        INSTALL_MODE remote REMOTE_TARGET_IP 10.1.1.1 TARGET_SEED_DIR "$seed"
    : >"$NDS_TEST_BIN_LOG"
    rc=0
    nds_cook "$out" >/dev/null 2>/dev/null || rc=$?
    log=$(<"$NDS_TEST_BIN_LOG")
    if [[ "$rc" -eq 0 && "$log" == *"nix run github:nix-community/nixos-anywhere -- "* \
        && "$log" == *"--extra-files ${seed}"* ]]; then
        bts_pass "flake remote passes --extra-files when a seed is set"
    else
        bts_fail "remote log was '${log}' rc ${rc}"
    fi

    bts_section "Hooks"
    _hook_early=
    _hook_pre() {
        if ! grep -q 'nix build ' "$NDS_TEST_BIN_LOG"; then
            _hook_early=1
        fi
    }
    eventRegister cook.pre_install _hook_pre
    : >"$NDS_TEST_BIN_LOG"
    _cook_variant "${_FIX}/flake_local.recipe" "$out" \
        FLAKE_LOCAL_PATH "$flake" FLAKE_INSTALL_PATH "${root}/etc/nixos" \
        ACCESS_ADMIN_PASSWORD_FILE "$pass" ENCRYPTION false
    rc=0
    nds_cook "$out" >/dev/null 2>/dev/null || rc=$?
    if [[ "$_hook_early" == 1 && "$rc" -eq 0 ]] && grep -q 'nix build ' "$NDS_TEST_BIN_LOG"; then
        bts_pass "pre_install hook runs before the build"
    else
        bts_fail "hook early was '${_hook_early}' rc ${rc}"
    fi
    eventUnregister cook.pre_install _hook_pre

    _hook_fail() { return 1; }
    eventRegister cook.pre_install _hook_fail
    : >"$NDS_TEST_BIN_LOG"
    rc=0
    nds_cook "$out" >/dev/null 2>/dev/null || rc=$?
    if [[ "$rc" -eq 1 ]] && ! grep -q 'nix build ' "$NDS_TEST_BIN_LOG"; then
        bts_pass "a failing pre_install hook aborts before the build"
    else
        bts_fail "failing hook rc was ${rc}"
    fi
    eventUnregister cook.pre_install _hook_fail

    export NDS_TEST_BIN_RC_GIT=1
    _cook_variant "${_FIX}/flake_local.recipe" "$out" \
        FLAKE_LOCAL_PATH "$flake" FLAKE_INSTALL_PATH "${root}/etc/nixos" \
        ACCESS_ADMIN_PASSWORD_FILE "$pass" ENCRYPTION false \
        LEAF_PUSH_DIR "$leaf" LEAF_PUSH_MESSAGE 'add host' GIT_KEYS_DIR "$keys"
    : >"$NDS_TEST_BIN_LOG"
    rc=0
    nds_cook "$out" >/dev/null 2>/dev/null || rc=$?
    unset NDS_TEST_BIN_RC_GIT
    if [[ "$rc" -eq 1 ]] && ! grep -q 'nixos-facter' "$NDS_TEST_BIN_LOG"; then
        bts_pass "a failed leaf push aborts before disk"
    else
        bts_fail "leaf fail rc was ${rc}"
    fi

    nds_test_assertResolved
    rm -rf "$flake" "$leaf" "$keys" "$seed" "$out"
    nds_test_stubBins_drop
    nds_test_session_drop
}
