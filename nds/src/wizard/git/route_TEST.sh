#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth route dispatch
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
logger_setMinLevel warn
import_dir "$(dirname "${BASH_SOURCE[0]}")" --depth 0

_route_host= _route_owner= _route_repo= _route_need= _route_reason=

suite_git_route() {
    local -A cfg=()
    if nds_git_auth_prompts cfg 2>/dev/null; then
        bts_fail "prompts succeeded without host, owner, and repo"
        return
    fi
    bts_pass "prompts require host, owner, and repo"
    nds_git_auth_wizard_step_repo() {
        _route_host=$1
        _route_owner=$2
        _route_repo=$3
        _route_need=$4
        _route_reason=$5
    }
    cfg[GIT_ACCESS_HOST]=github.com
    cfg[GIT_ACCESS_OWNER]=CodeAnthem
    cfg[GIT_ACCESS_REPO]=dp_cluster
    if nds_git_auth_prompts cfg write "This action git-pushes host files." \
        && [[ "$_route_host" == github.com && "$_route_owner" == CodeAnthem \
            && "$_route_repo" == dp_cluster && "$_route_need" == write \
            && "$_route_reason" == "This action git-pushes host files." ]]; then
        bts_pass "prompts dispatch the host, owner, repo, and need"
    else
        bts_fail "dispatch was ${_route_host} ${_route_owner} ${_route_repo} ${_route_need}"
    fi
}
