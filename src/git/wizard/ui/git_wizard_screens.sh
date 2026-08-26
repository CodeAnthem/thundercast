#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard screens (menu output)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-26
# ==================================================================================================

declare -ga NDS_GIT_AUTH_REGISTER_URLS=()

# Description: Ask whether to clear gh session on ISO after stop / failed run.
# Returns:
# - <Bool> 0 when user wants cleanup
nds_git_ui_ask_clear_gh_session() {
    nds_ui_b "A GitHub CLI (gh) login is still active on this live ISO."
    nds_ui_b "SSH deploy/account keys on GitHub are kept either way."
    nds_ui_b ""
    nds_ask_user_to_proceed "Clear the gh session from this ISO?"
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

    need="$(nds_git_access_normalize_need "$need")"
    if [[ -n "$repo_label" ]]; then
        nds_ui_b "${repo_label} is private."
    else
        nds_ui_b "This repository is private."
    fi
    if [[ "$need" == "write" ]]; then
        nds_ui_kv_row "Access" "write (clone and push)" 20
    else
        nds_ui_kv_row "Access" "read (clone)" 20
    fi
    [[ -n "$reason" ]] && nds_ui_kv_row "Reason" "$reason" 20
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

# Description: Print one repo line with optional status marker.
# Arguments:
# - url:    <String> Git remote URL
# - status: <String|optional> ok, missing, or empty
nds_git_wizard_print_repo() {
    local url="$1"
    local status="${2:-}"
    local ssh_url parsed host owner repo

    ssh_url=$(_nds_git_url_toSsh "$url")
    if parsed=$(_nds_git_url_parse "$ssh_url"); then
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        if [[ "$status" == "ok" ]]; then
            nds_ui_i "[ok]  ${host}/${owner}/${repo}"
        elif [[ "$status" == "missing" ]]; then
            nds_ui_i "[!!]  ${host}/${owner}/${repo}"
        else
            nds_ui_i "${host}/${owner}/${repo}"
        fi
    else
        nds_ui_i "${ssh_url}"
    fi
}

# Description: Collect deploy key registration URLs for manual path.
# Arguments:
# - urls: <String...> Git remote URLs
nds_git_wizard_collect_register_urls() {
    local url parsed host owner repo register_url
    NDS_GIT_AUTH_REGISTER_URLS=()
    for url in "$@"; do
        url=$(_nds_git_url_toSsh "$url")
        parsed=$(_nds_git_url_parse "$url") || continue
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        register_url="$(nds_git_deploy_key_register_url "$host" "$owner" "$repo")"
        [[ "$register_url" == http* ]] && NDS_GIT_AUTH_REGISTER_URLS+=("$register_url")
    done
}

# Description: List repositories with access status (closure check).
# Arguments:
# - urls_var:   <Nameref> All URLs checked
# - failed_var: <Nameref> URLs that failed probe
nds_git_wizard_screen_list_repos() {
    local -n _urls=$1
    local -n _failed=$2
    local url ssh_url parsed host owner repo key
    declare -A repo_status=() repo_sample=()

    for url in "${_urls[@]}"; do
        ssh_url=$(_nds_git_url_toSsh "$url")
        parsed=$(_nds_git_url_parse "$ssh_url") || continue
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        key="${owner}/${repo}"
        repo_sample[$key]="$url"
        [[ -z "${repo_status[$key]:-}" ]] && repo_status[$key]="ok"
    done
    for url in "${_failed[@]}"; do
        ssh_url=$(_nds_git_url_toSsh "$url")
        parsed=$(_nds_git_url_parse "$ssh_url") || continue
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        repo_status["${owner}/${repo}"]="missing"
        [[ -z "${repo_sample[${owner}/${repo}]:-}" ]] && repo_sample["${owner}/${repo}"]="$url"
    done
    while IFS= read -r key; do
        [[ -n "$key" ]] || continue
        nds_git_wizard_print_repo "${repo_sample[$key]}" "${repo_status[$key]}"
    done < <(printf '%s\n' "${!repo_status[@]}" | sort)
    nds_ui_b ""
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
    nds_git_wizard_collect_register_urls "$(_nds_git_url_formatSsh "$host" "$owner" "$repo")"
}

# Description: Screen when flake.lock inputs lack access.
# Arguments:
# - failed: <String...> URLs that failed probe
nds_git_wizard_screen_closure() {
    local -a failed=("$@")
    local -a all_urls=()
    local url

    nds_ui_section_header "Git access"
    nds_ui_b ""
    nds_ui_b "Related private repositories still need SSH access."
    nds_ui_b ""
    nds_git_wizard_collect_register_urls "${failed[@]}"

    if [[ -n "${NDS_GIT_CLOSURE_URLS:-}" ]]; then
        while IFS= read -r url; do
            [[ -n "$url" ]] && all_urls+=("$url")
        done <<< "${NDS_GIT_CLOSURE_URLS}"
    else
        all_urls=("${failed[@]}")
    fi

    nds_git_wizard_screen_list_repos all_urls failed
}
