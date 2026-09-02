#!/usr/bin/env bash
# ==================================================================================================
# tcast - smoke suite (package present; no network)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-01 | Modified: 2026-09-02
# ==================================================================================================

suite_tcast_smoke() {
    local root out
    root="${TCAST_ROOT:?}"

    if [[ -x "${root}/bin/tcast" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        bashTestSuite_ok "bin/tcast present"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        bashTestSuite_fail "missing tcast/bin/tcast"
    fi

    if [[ -x "${root}/bin/tcast-git-ssh" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        bashTestSuite_ok "bin/tcast-git-ssh present"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        bashTestSuite_fail "missing tcast-git-ssh"
    fi

    if [[ -f "${root}/package.nix" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        bashTestSuite_ok "package.nix present"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        bashTestSuite_fail "missing package.nix"
    fi

    out="$("${root}/bin/tcast" help 2>&1 || true)"
    if grep -q 'switch\|status\|restore' <<<"$out"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        bashTestSuite_ok "tcast help lists switch/status/restore"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        bashTestSuite_fail "tcast help unexpected"
    fi
}
