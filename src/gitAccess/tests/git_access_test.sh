#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git access logic unit checks (selftest suite fragment)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-26
# ==================================================================================================

# Description: Assert normalize + wants_gh + per-call write target helpers.
nds_git_access_logic_selfcheck() {
    local -A cfg=()
    cfg[FLAKE_REPO_URL]="https://github.com/CodeAnthem/dp_cluster.git"
    if ! nds_git_access_logic_normalize cfg; then
        return 1
    fi
    [[ "${cfg[GIT_ACCESS_OWNER]}" == "CodeAnthem" ]] || return 1
    [[ "${cfg[FLAKE_REPO_URL]}" == git@* ]] || return 1

    cfg[GIT_SSH_KEY_TYPE]="gh"
    nds_git_access_wants_gh_ui cfg || return 1

    [[ "$(nds_git_access_normalize_need write)" == "write" ]] || return 1
    [[ "$(nds_git_access_normalize_need read)" == "read" ]] || return 1
    export NDS_FLAKE_REPO_URL="${cfg[FLAKE_REPO_URL]}"
    nds_git_access_is_need_target "CodeAnthem" "dp_cluster" || return 1
    ! nds_git_access_is_need_target "CodeAnthem" "thundercore" || return 1
    [[ "$(nds_git_access_deploy_read_only CodeAnthem dp_cluster write)" == "false" ]] || return 1
    [[ "$(nds_git_access_deploy_read_only CodeAnthem thundercore write)" == "true" ]] || return 1
    [[ "$(nds_git_access_deploy_read_only CodeAnthem dp_cluster read)" == "true" ]] || return 1
    return 0
}
