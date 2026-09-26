#!/usr/bin/env bash
# ==================================================================================================
# NDS - Skip store
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
# shellcheck source=mode.sh
source "$(dirname "${BASH_SOURCE[0]}")/mode.sh"
# shellcheck source=skip.sh
source "$(dirname "${BASH_SOURCE[0]}")/skip.sh"

_skip_reset() {
    unset NDS_MODE NDS_YES NDS_SKIP NDS_SKIP_INSTALL_CONFIRM NDS_SKIP_NOT_A_NAME
}

suite_skip() {
    local rc=0 name

    bts_section "Decisions"
    _skip_reset
    export NDS_MODE=unattended
    nds_mode_resolve
    rc=0
    for name in action.preview cook.summary install.confirm finish.backup finish.reboot; do
        nds_skip "$name" || rc=1
    done
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "unattended skips every registered name"
    else
        bts_fail "unattended left a name unskipped"
    fi

    _skip_reset
    export NDS_MODE=interactive
    nds_mode_resolve
    export NDS_SKIP_INSTALL_CONFIRM=true
    if nds_skip install.confirm && ! nds_skip finish.reboot; then
        bts_pass "NDS_SKIP_INSTALL_CONFIRM skips that name"
    else
        bts_fail "per-name skip did not select install.confirm"
    fi

    unset NDS_SKIP_INSTALL_CONFIRM
    export NDS_SKIP=install.confirm
    if nds_skip install.confirm && ! nds_skip action.preview; then
        bts_pass "NDS_SKIP list skips that name"
    else
        bts_fail "NDS_SKIP list did not select install.confirm"
    fi

    unset NDS_SKIP
    export NDS_YES=true
    if nds_skip install.confirm && nds_skip finish.backup && ! nds_skip finish.reboot; then
        bts_pass "--yes skips every name except finish.reboot"
    else
        bts_fail "--yes did not keep finish.reboot"
    fi

    bts_section "Unknown names"
    _skip_reset
    export NDS_MODE=interactive
    nds_mode_resolve
    export NDS_SKIP=not.a.name
    rc=0
    nds_skip_startup 2>/dev/null || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        bts_pass "an unknown name in NDS_SKIP fails at startup"
    else
        bts_fail "unknown NDS_SKIP was accepted"
    fi

    unset NDS_SKIP
    export NDS_SKIP_NOT_A_NAME=true
    rc=0
    nds_skip_startup 2>/dev/null || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        bts_pass "an unknown NDS_SKIP_* name fails at startup"
    else
        bts_fail "unknown NDS_SKIP_* was accepted"
    fi

    unset NDS_SKIP_NOT_A_NAME
    rc=0
    nds_skip not.registered 2>/dev/null || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        bts_pass "nds_skip on an unregistered name fails"
    else
        bts_fail "unregistered nds_skip succeeded"
    fi
}
