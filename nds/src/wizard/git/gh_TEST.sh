#!/usr/bin/env bash
# ==================================================================================================
# NDS - gh binary wrappers used by the git screens
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
logger_setMinLevel warn
# shellcheck source=../../utilities/git/main.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../utilities/git/main.sh"

suite_gh_bin() {
    local log
    nds_test_stubBins gh
    gh_deviceLogin || { bts_fail "gh_deviceLogin failed"; return; }
    log=$(<"$NDS_TEST_BIN_LOG")
    if [[ "$log" == 'gh auth login --hostname github.com --git-protocol ssh --device' ]]; then
        bts_pass "gh_deviceLogin calls gh auth login --device"
    else
        bts_fail "gh log was '${log}'"
    fi
    nds_test_stubBins_drop
}
