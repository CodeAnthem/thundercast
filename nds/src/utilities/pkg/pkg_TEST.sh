#!/usr/bin/env bash
# ==================================================================================================
# pkg - resolve a binary that is already on PATH
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")" --depth 0

suite_pkg() {
    local -a cmd=()
    if pkg_cmd cmd bash && [[ "${cmd[0]}" == bash ]]; then
        bts_pass "pkg_cmd uses PATH when the binary exists"
    else
        bts_fail "pkg_cmd was '${cmd[*]-}'"
    fi
}
