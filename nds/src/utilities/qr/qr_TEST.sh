#!/usr/bin/env bash
# ==================================================================================================
# qr - empty payload is a no-op
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")" --depth 0

suite_qr() {
    local rc=0
    qr_print "" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "qr_print accepts an empty payload"
    else
        bts_fail "qr_print empty rc was ${rc}"
    fi
}
