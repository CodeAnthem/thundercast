#!/usr/bin/env bash
# ==================================================================================================
# NDS - Real main.sh under stubbed binaries
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../setup_TEST.sh"
logger_setMinLevel warn

_main_run() {
    local rc=0
    # setsid drops the controlling terminal so chrome cannot paint this session.
    # ROOTREEXEC_ROOT=false stops main.sh from exec'ing sudo.
    setsid -w env -i \
        PATH="$PATH" \
        HOME="${HOME:-/tmp}" \
        TMPDIR="${TMPDIR:-/tmp}" \
        NDS_TEST_BIN_DIR="$NDS_TEST_BIN_DIR" \
        NDS_TEST_BIN_LOG="$NDS_TEST_BIN_LOG" \
        ROOTREEXEC_ROOT=false \
        _NDS_TARGET_ROOT="$_NDS_TARGET_ROOT" \
        NDS_MODE=unattended \
        NDS_ENCRYPTION=false \
        NDS_NIXOS_STATE_VERSION=26.05 \
        NDS_BOOT_LOADER=grub \
        NDS_BOOT_UEFI_MODE=false \
        NDS_NETWORK_HOSTNAME=host \
        "$@" \
        bash "$(dirname "${BASH_SOURCE[0]}")/main.sh" --unattended \
        </dev/null >"${_main_out}" 2>"${_main_err}" || rc=$?
    printf '%s\n' "$rc"
}

suite_main() {
    local root flake rc log
    nds_test_session
    nds_test_installBins
    root=$_NDS_TARGET_ROOT
    export _NDS_TARGET_ROOT
    _main_out=$(mktemp)
    _main_err=$(mktemp)
    flake=$(mktemp -d)
    printf '%s\n' '{ outputs = { ... }: {}; }' > "${flake}/flake.nix"
    mkdir -p "${root}/git-keys"

    bts_section "Unattended"
    : >"$NDS_TEST_BIN_LOG"
    rc=$(_main_run NDS_ACTION=classicInstall NDS_DISK_TARGET=/dev/stubdisk)
    log=$(<"$NDS_TEST_BIN_LOG")
    if [[ "$rc" == 0 && "$log" == *"parted /dev/stubdisk "* \
        && "$log" == *"nixos-install --root ${root} "* \
        && "$log" != *'cryptsetup luksFormat'* ]] \
        && ! grep -q 'Start installation' "$_main_err"; then
        bts_pass "unattended classic partitions then runs nixos-install"
    else
        bts_fail "classic main rc was ${rc} log '${log}' err '$(tail -n 20 "$_main_err")'"
    fi

    bts_section "flake-owned disk"
    : >"$NDS_TEST_BIN_LOG"
    rc=$(_main_run NDS_ACTION=installFlake NDS_DISK_STRATEGY=flake \
        NDS_FLAKE_LOCATION=lab NDS_FLAKE_SOURCE=local NDS_FLAKE_LOCAL_PATH="$flake" \
        NDS_FLAKE_HOST=control NDS_GIT_KEYS_DIR="${root}/git-keys")
    log=$(<"$NDS_TEST_BIN_LOG")
    if [[ "$rc" == 0 && "$log" == *"nix build "* && "$log" != *prompt* ]]; then
        bts_pass "unattended flake-local builds the system from env"
    else
        bts_fail "flake main rc was ${rc} log '${log}' err '$(tail -n 30 "$_main_err")'"
    fi

    rm -rf "$flake"
    rm -f "$_main_out" "$_main_err"
    nds_test_stubBins_drop
    nds_test_session_drop
}
