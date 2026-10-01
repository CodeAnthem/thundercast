#!/usr/bin/env bash
# ==================================================================================================
# NDS - Mode
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-24 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
# shellcheck source=mode.sh
source "$(dirname "${BASH_SOURCE[0]}")/mode.sh"

_mode_reset() {
    unset NDS_MODE
}

suite_mode() {
    local rc=0

    bts_section "Resolve"
    _mode_reset
    nds_mode_resolve || { bts_fail "default resolve failed"; return; }
    if [[ "$NDS_MODE" == interactive ]] && nds_mode_is_interactive; then
        bts_pass "an unset mode stays interactive"
    else
        bts_fail "default mode was '${NDS_MODE}'"
    fi

    _mode_reset
    export NDS_MODE=unattended
    nds_mode_resolve || { bts_fail "unattended resolve failed"; return; }
    if nds_mode_is_unattended; then
        bts_pass "NDS_MODE=unattended stays unattended"
    else
        bts_fail "NDS_MODE=unattended left '${NDS_MODE}'"
    fi

    _mode_reset
    export NDS_MODE=interactive
    nds_mode_resolve || { bts_fail "interactive resolve failed"; return; }
    if nds_mode_is_interactive; then
        bts_pass "NDS_MODE=interactive stays interactive"
    else
        bts_fail "NDS_MODE=interactive left '${NDS_MODE}'"
    fi

    _mode_reset
    export NDS_MODE=bogus
    rc=0
    nds_mode_resolve 2>/dev/null || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        bts_pass "an invalid mode fails"
    else
        bts_fail "an invalid mode succeeded"
    fi
}
