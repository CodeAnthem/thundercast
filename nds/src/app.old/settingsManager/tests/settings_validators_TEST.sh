#!/usr/bin/env bash
# ==================================================================================================
# NDS - Validator unit tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# ==================================================================================================

suite_validators() {
    assert_valid ip "192.168.1.10"
    assert_invalid ip "256.1.1.1"
    assert_invalid ip "192.168.1.0"
    assert_invalid ip "192.168.1.255"
    assert_invalid ip "not-an-ip"

    assert_valid hostname "myhost"
    assert_valid hostname "my-host-01"
    assert_invalid hostname ""
    assert_invalid hostname "-bad"

    assert_valid path "/etc/nixos"
    assert_valid path "~/flakes"
    assert_valid path "./flake"
    assert_invalid path "relative-no-dot"

    if validate_path_classify "/abs" | grep -qx absolute \
       && validate_path_classify "~/flakes" | grep -qx home \
       && validate_path_classify "./rel" | grep -qx relative; then
        bts_pass "ok"
        console "  ✓ validate_path_classify: absolute/home/relative"
    else
        bts_fail "fail"
        console "  ✗ validate_path_classify"
    fi

    assert_valid git_remote "git@github.com:org/repo.git"
    assert_valid git_remote "https://github.com/org/repo.git"
    assert_invalid git_remote "not a url"

    if validate_git_url_classify "git@github.com:a/b.git" | grep -qx scp \
       && validate_git_url_classify "ssh://git@github.com/a/b.git" | grep -qx ssh-scheme \
       && validate_git_url_classify "https://x" | grep -qx https; then
        bts_pass "ok"
        console "  ✓ validate_git_url_classify: scp/ssh-scheme/https"
    else
        bts_fail "fail"
        console "  ✗ validate_git_url_classify"
    fi

    if nds_detect_flake_source "git@github.com:o/r.git" | grep -qx remote \
       && nds_detect_flake_source "/tmp/flake" | grep -qx local; then
        bts_pass "ok"
        console "  ✓ nds_detect_flake_source: remote/local"
    else
        bts_fail "fail"
        console "  ✗ nds_detect_flake_source"
    fi

    assert_valid toggle "yes"
    assert_valid toggle "false"
    assert_invalid toggle "maybe"
    if validate_toggle_normalize "Y" | grep -qx true && validate_toggle_normalize "0" | grep -qx false; then
        bts_pass "ok"
        console "  ✓ validate_toggle_normalize: Y/0"
    else
        bts_fail "fail"
        console "  ✗ validate_toggle_normalize"
    fi

    if validate_ip_same_subnet "192.168.1.10" "255.255.255.0" "192.168.1.1"; then
        bts_pass "ok"
        console "  ✓ validate_ip_same_subnet: same network"
    else
        bts_fail "fail"
        console "  ✗ validate_ip_same_subnet: same network"
    fi

    if ! validate_ip_same_subnet "192.168.1.10" "255.255.255.0" "10.0.0.1" 2>/dev/null; then
        bts_pass "ok"
        console "  ✓ validate_ip_same_subnet: rejects different network"
    else
        bts_fail "fail"
        console "  ✗ validate_ip_same_subnet: should reject different network"
    fi
}
