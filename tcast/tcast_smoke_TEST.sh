#!/usr/bin/env bash
# ==================================================================================================
# tcast - smoke suite (package present; no network)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-01 | Modified: 2026-09-23
# ==================================================================================================

suite_tcast_smoke() {
    local root out
    root="${TCAST_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)}"

    if [[ -x "${root}/bin/tcast" ]]; then
        bts_pass "bin/tcast present"
    else
        bts_fail "missing tcast/bin/tcast"
    fi

    if [[ -x "${root}/bin/tcast-git-ssh" ]]; then
        bts_pass "bin/tcast-git-ssh present"
    else
        bts_fail "missing tcast-git-ssh"
    fi

    if [[ -f "${root}/package.nix" ]]; then
        bts_pass "package.nix present"
    else
        bts_fail "missing package.nix"
    fi

    out="$("${root}/bin/tcast" help 2>&1 || true)"
    if grep -q 'switch\|status\|restore' <<<"$out"; then
        bts_pass "tcast help lists switch/status/restore"
    else
        bts_fail "tcast help unexpected"
    fi
}
