#!/usr/bin/env bash
# ==================================================================================================
# Git utility - GitHub CLI wrappers (PATH gh only)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-29 | Modified: 2026-08-31
# ==================================================================================================

declare -gA _GIT_GH_ACCOUNTS=()

# Description: Mark host/owner of this URL as using gh for all its repos.
# Arguments:
# - url: <String> Raw URL or safeUrl
# Returns:
# - <Bool> 0 when the account was recorded
git_gh_setAccountUsingGh() {
    local url="$1"
    local acc
    acc=${ git_store_getAccountUID "$url"; } || return 1
    _GIT_GH_ACCOUNTS["$acc"]="true"
}

# Description: True when the account of this URL uses gh.
# Arguments:
# - url: <String> Raw URL or safeUrl
# Returns:
# - <Bool> 0 when useGh is true
git_gh_isAccountUsingGh() {
    local url="$1"
    local acc safe envn
    acc=${ git_store_getAccountUID "$url"; } || return 1
    if [[ "${_GIT_GH_ACCOUNTS[$acc]:-}" == "true" ]]; then
        return 0
    fi
    safe="${acc//[^A-Za-z0-9]/_}"
    envn="GIT_ACCOUNT_${safe}_useGh"
    [[ "${!envn:-}" == "true" ]]
}

# Description: True when gh is on PATH.
# Returns:
# - <Bool> 0 when gh exists
git_gh_isAvailable() {
    command -v gh >/dev/null 2>&1
}

# Description: True when gh reports a logged-in session.
# Returns:
# - <Bool> 0 when authenticated
git_gh_isAuthenticated() {
    git_gh_isAvailable || return 1
    gh auth status >/dev/null 2>&1
}

# Description: Interactive gh auth login.
# Returns:
# - <Bool> 0 on success
git_gh_login() {
    git_gh_isAvailable || return 1
    gh auth login
}

# Description: gh auth logout.
# Returns:
# - <Bool> 0 on success
git_gh_logout() {
    git_gh_isAvailable || return 1
    gh auth logout
}

# Description: True when gh reports the repo private.
# Arguments:
# - slug: <String> owner/name
# Returns:
# - 0 private, 1 public, 2 unknown (gh missing or view failed)
git_gh_isRepoPrivate() {
    local slug="$1" priv
    git_gh_isAuthenticated || return 2
    priv="$(gh repo view "$slug" --json isPrivate --jq .isPrivate 2>/dev/null)" || return 2
    [[ "$priv" == "true" ]]
}

# Description: gh repo clone into dest.
# Arguments:
# - slug: <String> owner/name
# - dest: <String>
# Returns:
# - <Bool> 0 on success
git_gh_clone() {
    local slug="$1" dest="$2"
    git_gh_isAuthenticated || return 1
    mkdir -p "$(dirname "$dest")"
    gh repo clone "$slug" "$dest" -- --depth 1
}

# Description: Add a deploy key via gh.
# Arguments:
# - slug:     <String> owner/name
# - pub_file: <String> .pub path
# - title:    <String>
# - access:   <String> read|write
# Returns:
# - <Bool> 0 on success
git_gh_addDeployKey() {
    local slug="$1" pub_file="$2" title="$3" access="${4:-read}"
    local -a extra=()
    [[ -f "$pub_file" ]] || return 1
    git_gh_isAuthenticated || return 1
    [[ "$access" == "write" ]] && extra+=(--allow-write)
    gh repo deploy-key add "$pub_file" --repo "$slug" --title "$title" "${extra[@]}"
}

# Description: Record whether a leftover gh session existed at load.
# Returns:
# - <Bool> 0 after the lock file is written or skipped
git_gh_onLoad() {
    local lock="${GIT_WORKDIR:-}/gh.session"
    [[ -n "${GIT_WORKDIR:-}" ]] || return 0
    if git_gh_isAuthenticated; then
        printf '1\n' >"$lock"
    fi
}

# Description: Interactive: ask to logout. GIT_INTERACTIVE=0: try logout, keep session on failure.
# Returns:
# - <Bool> 0 after logout attempt or skip
git_gh_onExit() {
    local ans
    git_gh_isAuthenticated || return 0
    if git_helper_interactive_isEnabled; then
        printf 'Close GitHub CLI session? [Y/n] ' >&2
        read -r ans
        case "$ans" in
            n|N) return 0 ;;
        esac
        git_gh_logout || true
        return 0
    fi
    git_gh_logout || true
}
