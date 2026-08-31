#!/usr/bin/env bash
# ==================================================================================================
# Git utility - URL tryParse (validate + identity fields)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-08-31
# ==================================================================================================

# Description: True when tryParse accepts the URL.
# Arguments:
# - url: <String>
# Returns:
# - <Bool> 0 when valid
git_url_validate() {
    local -A id=()
    _git_url_tryParse id "${1:-}"
}

# Description: Validate and parse a git URL in one pass. On success fills dest
# with host, owner, repoName, provider. Provider is the host label before the
# first dot (github.com → github); dispatch falls back to generic when no
# git_<provider>_* exists. Query/fragment are stripped for parse.
# Arguments:
# - dest: <Nameref> Associative array to fill
# - url:  <String> Raw git URL
# Returns:
# - <Bool> 0 on success; 1 on failure (message via error)
_git_url_tryParse() {
    local -n _id="$1"
    local url="${2:-}"
    local work scheme host path owner repo provider

    if [[ -z "$url" ]]; then
        err "URL is empty"
        return 1
    fi
    if [[ "$url" == *[[:space:]]* ]]; then
        err "URL contains whitespace"
        return 1
    fi

    work="$url"
    work="${work%%#*}"
    work="${work%%\?*}"
    if [[ -z "$work" ]]; then
        err "URL is empty after stripping query/fragment"
        return 1
    fi

    if [[ "$work" == git+ssh://* ]]; then
        work="${work#git+ssh://}"
        scheme="git+ssh"
    elif [[ "$work" == *://* ]]; then
        scheme="${work%%://*}"
        work="${work#*://}"
        case "$scheme" in
            https|http|ssh|git) ;;
            *)
                err "Invalid protocol: '$scheme'"
                return 1
                ;;
        esac
    elif [[ "$work" == *@*:* ]]; then
        scheme="scp"
    else
        err "URL has no supported scheme"
        return 1
    fi

    if [[ "$scheme" == "scp" ]]; then
        work="${work#*@}"
        host="${work%%:*}"
        path="${work#*:}"
    else
        work="${work#*@}"
        if [[ "$work" != */* ]]; then
            err "URL contains no path"
            return 1
        fi
        host="${work%%/*}"
        path="${work#*/}"
    fi

    path="${path%.git}"
    path="${path%/}"
    if [[ -z "$host" || "$path" != */* ]]; then
        err "URL host or path is incomplete"
        return 1
    fi
    if [[ "$host" == *[[:space:]]* || "$host" == *"@"* ]]; then
        err "Host contains whitespace or '@'"
        return 1
    fi

    owner="${path%/*}"
    repo="${path##*/}"
    if [[ -z "$owner" || -z "$repo" ]]; then
        err "URL contains no owner or repository"
        return 1
    fi
    if [[ ! "$owner" =~ ^[A-Za-z0-9._-]+$ ]]; then
        err "Owner contains invalid characters"
        return 1
    fi
    if [[ ! "$repo" =~ ^[A-Za-z0-9._-]+$ ]]; then
        err "Repository contains invalid characters"
        return 1
    fi

    provider="${host%%.*}"
    provider="${provider//[^A-Za-z0-9]/_}"
    if [[ -z "$provider" ]]; then
        err "Provider label is empty"
        return 1
    fi

    _id=()
    _id[host]="$host"
    _id[owner]="$owner"
    _id[repoName]="$repo"
    _id[provider]="$provider"
}
