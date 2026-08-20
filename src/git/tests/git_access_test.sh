#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git access logic unit checks (selftest suite fragment)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# ==================================================================================================

# Description: Assert normalize + wants_gh helpers (called from suite_git when present).
nds_git_access_logic_selfcheck() {
    local -A cfg=()
    cfg[FLAKE_REPO_URL]="https://github.com/CodeAnthem/dps_swarm.git"
    if ! nds_git_access_logic_normalize cfg; then
        return 1
    fi
    [[ "${cfg[GIT_ACCESS_OWNER]}" == "CodeAnthem" ]] || return 1
    [[ "${cfg[FLAKE_REPO_URL]}" == git@* ]] || return 1

    cfg[GIT_SSH_KEY_TYPE]="gh"
    nds_git_access_wants_gh_ui cfg || return 1
    return 0
}
