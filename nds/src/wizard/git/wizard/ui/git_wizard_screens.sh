#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard screens (menu output)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-09-04
# ==================================================================================================

declare -ga NDS_GIT_AUTH_REGISTER_URLS=()

# Description: Ask whether to clear gh session on ISO after stop / failed run.
# Returns:
# - <Bool> 0 when user wants cleanup
nds_git_ui_ask_clear_gh_session() {
    nds_ui_b "A GitHub CLI (gh) login is still active on this live ISO."
    nds_ui_b "SSH deploy/account keys on GitHub are kept either way."
    nds_ui_b ""
    nds_ask_user_to_proceed "Clear the gh session from this ISO?" n
}

# Description: Intro for a private-repo SSH wizard (boxed header, then this repo).
# Arguments:
# - need:       <String|optional> read (default) or write
# - reason:     <String|optional> Why this access is required
# - repo_label: <String|optional> host/owner/repo (named once here)
nds_git_wizard_screen_need_blurb() {
    local need="${1:-read}"
    local reason="${2:-}"
    local repo_label="${3:-}"

    need="${ nds_git_access_normalize_need "$need"; }"
    if [[ -n "$repo_label" ]]; then
        nds_ui_b "${repo_label} is private."
    else
        nds_ui_b "This repository is private."
    fi
    if [[ "$need" == "write" ]]; then
        nds_ui_kv_row "Permission" "read & write" 20
    else
        nds_ui_kv_row "Permission" "read only" 20
    fi
    [[ -n "$reason" ]] && nds_ui_kv_row "Purpose" "$reason" 20
}

nds_git_wizard_screen_intro() {
    local need="${1:-read}"
    local reason="${2:-}"
    local repo_label="${3:-}"

    nds_ui_section_header "Git access"
    nds_ui_b ""
    nds_git_wizard_screen_need_blurb "$need" "$reason" "$repo_label"
    nds_ui_b ""
}

# Description: Collect deploy key registration URLs for manual path.
# Arguments:
# - urls: <String...> Git remote URLs
nds_git_wizard_collect_register_urls() {
    local url parsed host owner repo register_url
    NDS_GIT_AUTH_REGISTER_URLS=()
    for url in "$@"; do
        url=${ _nds_git_url_toSsh "$url"; }
        parsed=${ _nds_git_url_parse "$url"; } || continue
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        register_url="${ nds_git_deploy_key_register_url "$host" "$owner" "$repo"; }"
        [[ "$register_url" == http* ]] && NDS_GIT_AUTH_REGISTER_URLS+=("$register_url")
    done
}

# Description: Screen for a single root flake repo.
# Arguments:
# - host:   <String> Git host
# - owner:  <String> Repo owner
# - repo:   <String> Repo name
# - need:   <String|optional> read (default) or write
# - reason: <String|optional> Why this access is required
nds_git_wizard_screen_single() {
    local host="$1" owner="$2" repo="$3"
    local need="${4:-read}"
    local reason="${5:-}"

    nds_git_wizard_screen_intro "$need" "$reason" "${host}/${owner}/${repo}"
    nds_git_wizard_collect_register_urls "${ _nds_git_url_formatSsh "$host" "$owner" "$repo"; }"
}
