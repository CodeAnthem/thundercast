#!/usr/bin/env bash
# ==================================================================================================
# Git utility - GitHub provider remote ops (dispatch: isPrivate, pull, push, deploy keys)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-29 | Modified: 2026-08-31
# ==================================================================================================

# Description: owner/repoName slug from the store.
# Arguments:
# - safeUrl: <String> Indexed safeUrl
# Returns:
# - <String> owner/repoName (stdout)
_git_github_getSlug() {
    local safeUrl="$1"
    local owner repoName
    owner=${ git_store_get "$safeUrl" owner; } || return 1
    repoName=${ git_store_get "$safeUrl" repoName; }
    printf '%s/%s' "$owner" "$repoName"
}

# Description: gh view when authenticated, else generic ls-remote.
# Arguments:
# - safeUrl: <String> Indexed safeUrl
# Returns:
# - stdout true|false
git_github_isPrivate() {
    local safeUrl="$1"
    local slug rc
    slug=${ _git_github_getSlug "$safeUrl"; } || return 1
    if git_gh_isAuthenticated; then
        git_gh_isRepoPrivate "$slug"
        rc=$?
        case "$rc" in
            0)
                printf '%s' "true"
                return 0
                ;;
            1)
                printf '%s' "false"
                return 0
                ;;
        esac
    fi
    git_generic_isPrivate "$safeUrl"
}

# Description: gh clone/fetch when the account uses gh, else generic git.
# Arguments:
# - safeUrl: <String> Indexed safeUrl
# Returns:
# - <Bool> 0 on success
git_github_pull() {
    local safeUrl="$1"
    local dest slug
    dest=${ git_store_getTargetDir "$safeUrl"; } || return 1
    if git_gh_isAccountUsingGh "$safeUrl"; then
        slug=${ _git_github_getSlug "$safeUrl"; } || return 1
        if [[ -d "$dest/.git" ]]; then
            git -C "$dest" fetch
            return $?
        fi
        git_gh_clone "$slug" "$dest" || {
            err "gh clone failed: $slug"
            return 1
        }
        return 0
    fi
    git_generic_pull "$safeUrl"
}

# Description: Push via generic git protocol.
# Arguments:
# - safeUrl: <String> Indexed safeUrl
# Returns:
# - <Bool> 0 on success
git_github_push() {
    git_generic_push "$1"
}

# Description: Add a deploy key through gh.
# Arguments:
# - safeUrl: <String> Indexed safeUrl
# - pub:     <String|optional> .pub path
# - title:   <String|optional>
# Returns:
# - <Bool> 0 on success
git_github_addDeployKey() {
    local safeUrl="$1"
    local pub="${2:-}"
    local title="${3:-}"
    local slug access key_path needWrite
    slug=${ _git_github_getSlug "$safeUrl"; } || return 1
    needWrite=${ git_store_get "$safeUrl" needWrite; }
    if [[ "$needWrite" == "true" ]]; then
        access="write"
    else
        access="read"
    fi
    key_path=${ git_store_get "$safeUrl" keyPath; }
    [[ -n "$pub" ]] || pub="${key_path}.pub"
    [[ -n "$title" ]] || title="git"
    [[ -f "$pub" ]] || {
        err "public key missing: $pub"
        return 1
    }
    git_gh_addDeployKey "$slug" "$pub" "$title" "$access"
}

# Description: GitHub deploy-key remove is not implemented.
# Arguments:
# - safeUrl: <String>
# Returns:
# - <Bool> always 1
git_github_removeDeployKey() {
    err "not implemented"
    return 1
}
