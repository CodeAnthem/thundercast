#!/usr/bin/env bash
# ==================================================================================================
# Git utility - store info plugin (targetDir + URL forms)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-30 | Modified: 2026-08-31
# ==================================================================================================

# Description: Store derived identity fields and targetDir. No network.
# Fields: accountUID, repoUID, urlHttps, urlSsh, targetDir.
# Arguments:
# - safeUrl: <String> Indexed safeUrl
# Returns:
# - <Bool> 0 when set
_git_store_info_index() {
    local safeUrl="$1"
    local host owner repoName provider target

    host=${ git_store_get "$safeUrl" host; } || return 1
    owner=${ git_store_get "$safeUrl" owner; }
    repoName=${ git_store_get "$safeUrl" repoName; }
    provider=${ git_store_get "$safeUrl" provider; }

    git_store_set "$safeUrl" accountUID "${host}/${owner}"
    git_store_set "$safeUrl" repoUID "${provider}_${owner}_${repoName}"
    git_store_set "$safeUrl" urlHttps "https://${host}/${owner}/${repoName}.git"
    git_store_set "$safeUrl" urlSsh "git@${host}:${owner}/${repoName}.git"

    _git_store_overlayEnv "$safeUrl" targetDir
    target=${ git_store_get "$safeUrl" targetDir; }
    if [[ -z "$target" ]]; then
        git_store_set "$safeUrl" targetDir "${GIT_WORKDIR:?}/git_repo/${safeUrl}"
    fi
}

# Description: Account UID for a URL: host/owner.
# Arguments:
# - url: <String> Raw URL or safeUrl
# Returns:
# - <String> host/owner (stdout)
# - <Bool> 0 when indexed
git_store_getAccountUID() {
    git_store_get "$1" accountUID
}

# Description: Repo UID for a URL: provider_owner_repoName.
# Arguments:
# - url: <String> Raw URL or safeUrl
# Returns:
# - <String> provider_owner_repoName (stdout)
# - <Bool> 0 when indexed
git_store_getRepoUID() {
    git_store_get "$1" repoUID
}

# Description: Clone directory for a URL under GIT_WORKDIR.
# Arguments:
# - url: <String> Raw URL or safeUrl
# Returns:
# - <String> Target path (stdout)
# - <Bool> 0 when indexed
git_store_getTargetDir() {
    git_store_get "$1" targetDir
}

# Description: HTTPS git URL from stored identity.
# Arguments:
# - url: <String> Raw URL or safeUrl
# Returns:
# - <String> https://host/owner/repo.git (stdout)
# - <Bool> 0 when indexed
git_store_getUrlHttps() {
    git_store_get "$1" urlHttps
}

# Description: SSH git URL from stored identity.
# Arguments:
# - url: <String> Raw URL or safeUrl
# Returns:
# - <String> git@host:owner/repo.git (stdout)
# - <Bool> 0 when indexed
git_store_getUrlSsh() {
    git_store_get "$1" urlSsh
}

# Description: Indexed HTTPS URLs that share an account UID.
# Arguments:
# - accountUID: <String> host/owner
# Returns:
# - <String> One HTTPS URL per line (stdout)
git_store_getAllReposOfAccountUID() {
    local accountUID="$1"
    local safeUrl acc

    for safeUrl in "${_GIT_STORE_URLS[@]+"${_GIT_STORE_URLS[@]}"}"; do
        acc=${ git_store_get "$safeUrl" accountUID; }
        if [[ "$acc" == "$accountUID" ]]; then
            git_store_get "$safeUrl" urlHttps
            printf '\n'
        fi
    done
}
