#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install log compose
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-25 | Modified: 2026-09-25
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
# shellcheck source=install_logs.sh
source "$(dirname "${BASH_SOURCE[0]}")/install_logs.sh"

suite_install_logs() {
    local dir session detail diag dest body rc=0

    bts_section "Compose"
    rc=0
    nds_session_logs_compose "" 2>/dev/null || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        bts_pass "an empty destination fails"
    else
        bts_fail "empty destination was accepted"
    fi

    dir=$(mktemp -d)
    session="${dir}/session.log"
    detail="${dir}/detail.log"
    diag="${dir}/diag.log"
    dest="${dir}/nds.log"
    printf '%s\n' 'SESSION-MARK' >"$session"
    printf '%s\n' 'DETAIL-MARK' >"$detail"
    printf '%s\n' 'DIAG-MARK' >"$diag"
    nds_session_logs_compose "$dest" "$session" "$detail" "$diag" || { bts_fail "compose failed"; rm -rf "$dir"; return; }
    body=$(<"$dest")
    rm -rf "$dir"
    if [[ "$body" == *'1. Session'* && "$body" == *SESSION-MARK* && "$body" == *'2. Install steps'* && "$body" == *DETAIL-MARK* && "$body" == *'3. Diagnostics'* && "$body" == *DIAG-MARK* ]]; then
        bts_pass "compose writes session, steps, and diagnostics into one file"
    else
        bts_fail "compose missed a section"
    fi
}
