#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git URL and key helpers
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
logger_setMinLevel warn
import_dir "$(dirname "${BASH_SOURCE[0]}")/../../recipe" --depth 0
import_dir "$(dirname "${BASH_SOURCE[0]}")" --depth 0

suite_git_access() {
    local -A cfg=()
    local _got
    cfg[FLAKE_REPO_URL]="https://github.com/CodeAnthem/dp_cluster.git"
    nds_git_access_logic_normalize cfg || { bts_fail "normalize failed"; return; }
    if [[ "${cfg[GIT_ACCESS_OWNER]}" == CodeAnthem && "${cfg[FLAKE_REPO_URL]}" == git@* ]]; then
        bts_pass "https URL normalizes to ssh and keeps the owner"
    else
        bts_fail "owner='${cfg[GIT_ACCESS_OWNER]}' url='${cfg[FLAKE_REPO_URL]}'"
    fi
    cfg[GIT_SSH_KEY_TYPE]=gh
    if nds_git_access_wants_gh_ui cfg; then
        bts_pass "gh route wants the gh screen"
    else
        bts_fail "gh route was not detected"
    fi
    export NDS_FLAKE_REPO_URL="${cfg[FLAKE_REPO_URL]}"
    if nds_git_access_is_need_target CodeAnthem dp_cluster \
        && ! nds_git_access_is_need_target CodeAnthem thundercore; then
        bts_pass "write target is the flake repo"
    else
        bts_fail "need target mismatch"
    fi
    _got=$(nds_git_access_deploy_read_only CodeAnthem dp_cluster write)
    if [[ "$_got" == false ]]; then
        bts_pass "the flake repo deploy key is writable"
    else
        bts_fail "flake deploy read-only was '${_got}'"
    fi
    _got=$(nds_git_access_deploy_read_only CodeAnthem thundercore write)
    if [[ "$_got" == true ]]; then
        bts_pass "a closure repo deploy key stays read-only"
    else
        bts_fail "closure deploy read-only was '${_got}'"
    fi
}
