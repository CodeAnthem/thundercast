#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git access prompts and hints
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-26
# Description:   Auth wizard entry + leftover-session / deploy-key hints
# ==================================================================================================
# Description: Run repo auth wizard for host/owner/repo from cfg AA.
# Arguments:
# - cfg:    <Nameref> Config AA (GIT_ACCESS_HOST/OWNER/REPO)
# - need:   <String|optional> read (default) or write
# - reason: <String|optional> Why this access is required
nds_git_auth_prompts() {
    local -n _g_p=$1
    local need="${2:-read}"
    local reason="${3:-}"
    local host="${_g_p[GIT_ACCESS_HOST]:-}"
    local owner="${_g_p[GIT_ACCESS_OWNER]:-}"
    local repo="${_g_p[GIT_ACCESS_REPO]:-}"

    if [[ -z "$host" || -z "$owner" || -z "$repo" ]]; then
        error "Git auth prompts need GIT_ACCESS_HOST/OWNER/REPO in config AA"
        return 1
    fi

    nds_git_auth_wizard_step_repo "$host" "$owner" "$repo" "$need" "$reason"
}

# Description: Blank line then ask whether to clear leftover gh session (existing ask).
nds_git_ui_offer_clear_gh_session() {
    nds_ui_b ""
    nds_git_ui_ask_clear_gh_session
}

# Description: Show deploy-key registration URL hint for a GitHub repo.
# Arguments:
# - owner: <String>
# - repo:  <String>
nds_git_ui_deploy_key_hint() {
    local owner="$1" repo="$2"
    nds_ui_i "Deploy keys: https://github.com/${owner}/${repo}/settings/keys"
}
