#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git URL utilities (standalone)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-08-31
# Description:   Parse and normalize git remote URLs (argument-only; no NDS config)
# ==================================================================================================

# Description: Split a git URL into host, owner, repo (repo without .git suffix).
# Arguments:
# - url: <String> Git URL
# Returns:
# - <String> "host<TAB>owner<TAB>repo" on stdout, non-zero when unparseable
_nds_git_url_parse() {
    local url="$1" host path rest
    case "$url" in
        *://*)
            rest="${url#*://}"
            rest="${rest#*@}"
            host="${rest%%/*}"
            path="${rest#*/}"
            ;;
        *@*:*)
            rest="${url#*@}"
            host="${rest%%:*}"
            path="${rest#*:}"
            ;;
        *)
            return 1
            ;;
    esac
    path="${path%.git}"
    path="${path%/}"
    [[ "$path" == */* ]] || return 1
    printf '%s\t%s\t%s\n' "$host" "${path%/*}" "${path##*/}"
}

_nds_git_url_formatSsh() { printf 'git@%s:%s/%s.git\n' "$1" "$2" "$3"; }

# Description: Lowercase filesystem slug from a git remote owner (org or user).
# Arguments:
# - url: <String> Git remote URL
# Returns:
# - <String> slug on stdout (e.g. codeanthem), or "unknown"
nds_git_owner_slug() {
    local url="${1:-}"
    local parsed host owner repo slug

    [[ -n "$url" ]] || { printf 'unknown\n'; return 0; }

    url=$(_nds_git_url_toSsh "$url")
    parsed=$(_nds_git_url_parse "$url") || { printf 'unknown\n'; return 0; }
    IFS=$'\t' read -r host owner repo <<< "$parsed"
    [[ -n "$owner" ]] || { printf 'unknown\n'; return 0; }

    slug=$(printf '%s' "$owner" | tr '[:upper:]' '[:lower:]')
    slug=$(printf '%s' "$slug" | sed -e 's/[^a-z0-9]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//')
    [[ -n "$slug" ]] && printf '%s\n' "$slug" || printf 'unknown\n'
}

# Description: Normalize a remote URL to canonical git@host:owner/repo.git for git operations.
# Arguments:
# - url: <String> Git URL
# Returns:
# - <String> SSH URL on stdout (unchanged when unparseable)
_nds_git_url_toSsh() {
    local url="$1" out
    out=${ git_url_toSsh "$url"; } || {
        printf '%s\n' "$url"
        return 0
    }
    printf '%s\n' "$out"
}

# Description: True when every URL resolves to a GitHub host.
# Arguments:
# - urls: <String...> Git remote URLs
# Returns:
# - <Bool> 0 when all URLs are github.com
nds_git_urls_all_github() {
    local url ssh_url parsed host owner repo
    for url in "$@"; do
        [[ -n "$url" ]] || continue
        ssh_url=$(_nds_git_url_toSsh "$url")
        parsed=$(_nds_git_url_parse "$ssh_url") || return 1
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        nds_git_host_is_github "$host" || return 1
    done
    return 0
}

# Description: host/owner/repo for wizard prompts (stdout; raw URL when unparseable).
# Arguments:
# - url: <String> Git remote URL
nds_git_url_display() {
    local url="$1" parsed host owner repo
    parsed=$(_nds_git_url_parse "$(_nds_git_url_toSsh "$url")") || {
        printf '%s\n' "$url"
        return 0
    }
    IFS=$'\t' read -r host owner repo <<< "$parsed"
    printf '%s/%s/%s\n' "$host" "$owner" "$repo"
}
