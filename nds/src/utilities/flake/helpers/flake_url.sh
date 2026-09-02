#!/usr/bin/env bash
# ==================================================================================================
# Flake utility - URL normalize for discovery dedupe (NDS-free, no git store)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-08-31
# ==================================================================================================

# Description: Normalize a git remote URL to git@host:owner/repo.git when parseable.
# Arguments:
# - url: <String> Raw git URL
# Returns:
# - <String> Normalized SSH URL, or original when unparseable (stdout)
_flake_url_toSsh() {
    local url="${1:-}" host path rest owner repo

    [[ -n "$url" ]] || return 0
    case "$url" in
        git+ssh://*) url="${url#git+ssh://}" ;;
    esac
    case "$url" in
        *@*) ;;
        */*) url="git@${url}" ;;
    esac
    case "$url" in
        git@*:*/*) ;;
        git@*/*)
            rest="${url#git@}"
            url="git@${rest%%/*}:${rest#*/}"
            ;;
    esac

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
            printf '%s\n' "$url"
            return 0
            ;;
    esac
    path="${path%.git}"
    path="${path%/}"
    [[ "$path" == */* ]] || {
        printf '%s\n' "$url"
        return 0
    }
    owner="${path%/*}"
    repo="${path##*/}"
    printf 'git@%s:%s/%s.git\n' "$host" "$owner" "$repo"
}

# Description: Rewrite a lock URL for builtins.fetchTree.
# Arguments:
# - url: <String> Git URL from flake.lock
# Returns:
# - <String> fetchTree url field (stdout)
flake_fetchTreeUrl() {
    local url="${1:-}"

    case "$url" in
        git+ssh://*) printf 'ssh://%s\n' "${url#git+ssh://}" ;;
        ssh://*) printf '%s\n' "$url" ;;
        git@*:*/*)
            local hostpath="${url#git@}"
            hostpath="${hostpath/:/\/}"
            printf 'ssh://git@%s\n' "$hostpath"
            ;;
        *) _flake_url_toSsh "$url" ;;
    esac
}
