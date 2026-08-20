#!/usr/bin/env bash
# ==================================================================================================
# NDS - Shared tools selfchecks
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-16
# ==================================================================================================

suite_tools_lib() {
    if declare -f nds_pkg_cmd &>/dev/null \
        && declare -f nds_qr_print &>/dev/null \
        && declare -f nds_gh_ensure &>/dev/null \
        && declare -f nds_gh_session_cleanup &>/dev/null \
        && declare -f nds_gh_register_deploy_key &>/dev/null \
        && declare -f nds_age_keygen &>/dev/null \
        && declare -f nds_facter_write &>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ tools: pkg/qr/gh(+session/api)/age/facter loaded"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ tools: helpers missing"
    fi

    if [[ -d "${SCRIPT_DIR}/git/github" ]]; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ git/github still present (should be tools nds_gh_*)"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ git/github removed (GH is tools)"
    fi

    if declare -f nds_pkg_cmd &>/dev/null; then
        local -a cmd=()
        if command -v bash &>/dev/null && nds_pkg_cmd cmd bash bash \
            && [[ "${cmd[0]}" == "bash" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ pkg_cmd: resolves PATH binary"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ pkg_cmd: PATH resolve"
        fi
    fi

    if declare -f _nds_gh_store_path_from_output &>/dev/null; then
        local store_line
        store_line=$(_nds_gh_store_path_from_output \
            $'copying path \'/nix/store/aaa-foo\' from cache...\n  /nix/store/bbb-gh-2.74.0\n/nix/store/bbb-gh-2.74.0\n')
        if [[ "$store_line" == "/nix/store/bbb-gh-2.74.0" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ gh store path: last unindented /nix/store line"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ gh store path: got ${store_line}"
        fi
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ gh store path helper missing"
    fi

    if declare -f nds_git_gh_ensure &>/dev/null \
        || declare -f nds_git_gh_cmd &>/dev/null \
        || declare -f nds_git_gh_session_cleanup &>/dev/null; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ leftover nds_git_gh_* aliases (use nds_gh_*)"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ no nds_git_gh_* aliases (nds_gh_* only)"
    fi
}
