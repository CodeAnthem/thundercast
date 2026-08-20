#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth prompts selfcheck (stubbed wizard)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# Description:   AA key gate + prompts dispatch without TTY
# ==================================================================================================

# Description: Assert prompts require AA keys and call wizard with host/owner/repo.
nds_git_auth_prompts_selfcheck() {
    local -A cfg=()
    local got_host="" got_owner="" got_repo=""
    local saved_wizard=""

    if nds_git_auth_prompts cfg 2>/dev/null; then
        return 1
    fi

    if declare -f nds_git_auth_wizard_step_repo &>/dev/null; then
        saved_wizard="$(declare -f nds_git_auth_wizard_step_repo)"
    fi

    nds_git_auth_wizard_step_repo() {
        got_host="$1"
        got_owner="$2"
        got_repo="$3"
        return 0
    }

    cfg[GIT_ACCESS_HOST]="github.com"
    cfg[GIT_ACCESS_OWNER]="CodeAnthem"
    cfg[GIT_ACCESS_REPO]="dps_swarm"
    if ! nds_git_auth_prompts cfg \
        || [[ "$got_host" != "github.com" ]] \
        || [[ "$got_owner" != "CodeAnthem" ]] \
        || [[ "$got_repo" != "dps_swarm" ]]; then
        unset -f nds_git_auth_wizard_step_repo 2>/dev/null || true
        [[ -n "$saved_wizard" ]] && eval "$saved_wizard"
        return 1
    fi

    unset -f nds_git_auth_wizard_step_repo 2>/dev/null || true
    [[ -n "$saved_wizard" ]] && eval "$saved_wizard"
    return 0
}
