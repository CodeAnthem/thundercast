#!/usr/bin/env bash
# ==================================================================================================
# NDS - Repo-aware SSH for git+ssh (deploy keys)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-08 | Modified: 2026-08-20
# Description:   Pick IdentityFile from tc-git.map / nds-git.map by owner/repo.
#                Installed to /root/.ssh/nds-git-ssh; used via GIT_SSH_COMMAND.
# Map format:    owner/repo<TAB>/absolute/key/path   (lowercase owner/repo)
# Optional env:  NDS_GIT_SSH_ROOT — prefix for paths (e.g. /mnt during ISO verify)
#                tc-git-ssh init [owner/repo] [keyfile] — works on GUI NixOS too
# ==================================================================================================
set -euo pipefail

_nds_git_ssh_default_map() {
    if [[ -n "${NDS_GIT_SSH_MAP:-}" ]]; then
        printf '%s\n' "$NDS_GIT_SSH_MAP"
        return 0
    fi
    if [[ -n "${TC_GIT_SSH_MAP:-}" ]]; then
        printf '%s\n' "$TC_GIT_SSH_MAP"
        return 0
    fi
    local cand
    for cand in \
        "${HOME}/.ssh/tc-git.map" \
        "${HOME}/.ssh/nds-git.map" \
        "/root/.ssh/tc-git.map" \
        "/root/.ssh/nds-git.map"
    do
        if [[ -f "$cand" ]]; then
            printf '%s\n' "$cand"
            return 0
        fi
    done
    printf '%s\n' "${HOME}/.ssh/tc-git.map"
}

MAP="$(_nds_git_ssh_default_map)"
ROOT_PREFIX="${NDS_GIT_SSH_ROOT:-}"
SSH_BIN="${NDS_GIT_SSH_BIN:-ssh}"

# Description: Add owner/repo + IdentityFile to the map (GUI NixOS / any machine).
_nds_git_ssh_init() {
    local repo="${1:-}" key="${2:-}"
    MAP="${NDS_GIT_SSH_MAP:-${TC_GIT_SSH_MAP:-${HOME}/.ssh/tc-git.map}}"
    mkdir -p "$(dirname "$MAP")"
    chmod 700 "$(dirname "$MAP")" 2>/dev/null || true
    if [[ -z "$repo" ]]; then
        if [[ -e /dev/tty ]]; then
            read -rp "owner/repo: " repo < /dev/tty
            read -rp "absolute path to SSH private key: " key < /dev/tty
        else
            echo "usage: tc-git-ssh init owner/repo /absolute/path/to/key" >&2
            return 1
        fi
    fi
    repo="${repo,,}"
    repo="${repo%.git}"
    [[ "$repo" == */* ]] || {
        echo "tc-git-ssh init: expected owner/repo, got '${repo}'" >&2
        return 1
    }
    [[ -n "$key" && "$key" == /* ]] || {
        echo "tc-git-ssh init: key path must be absolute" >&2
        return 1
    }
    [[ -f "$key" ]] || echo "tc-git-ssh init: warning: key file not found yet: ${key}" >&2
    touch "$MAP"
    chmod 600 "$MAP"
    if grep -q "^${repo}"$'\t' "$MAP" 2>/dev/null; then
        echo "tc-git-ssh init: ${repo} already in ${MAP}" >&2
        return 0
    fi
    printf '%s\t%s\n' "$repo" "$key" >>"$MAP"
    echo "tc-git-ssh init: ${repo} -> ${key} (${MAP})"
    echo "Use:  export GIT_SSH_COMMAND=$(command -v tc-git-ssh 2>/dev/null || command -v nds-git-ssh || echo tc-git-ssh)"
}

if [[ "${1:-}" == init || "${1:-}" == --init ]]; then
    shift
    _nds_git_ssh_init "$@"
    exit $?
fi

_nds_git_ssh_extract_repo() {
    local arg owner repo
    for arg in "$@"; do
        if [[ "$arg" =~ ([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)(\.git)?([\"\']|$) ]]; then
            owner="${BASH_REMATCH[1],,}"
            repo="${BASH_REMATCH[2],,}"
            repo="${repo%.git}"
            printf '%s/%s\n' "$owner" "$repo"
            return 0
        fi
        if [[ "$arg" =~ git@[^:]+:([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)(\.git)?$ ]]; then
            owner="${BASH_REMATCH[1],,}"
            repo="${BASH_REMATCH[2],,}"
            repo="${repo%.git}"
            printf '%s/%s\n' "$owner" "$repo"
            return 0
        fi
    done
    return 1
}

_nds_git_ssh_lookup_key() {
    local want="$1" line kpath

    [[ -f "${ROOT_PREFIX}${MAP}" ]] || [[ -f "$MAP" ]] || return 1
    local mapfile="$MAP"
    [[ -f "${ROOT_PREFIX}${MAP}" ]] && mapfile="${ROOT_PREFIX}${MAP}"

    while IFS=$'\t' read -r line kpath || [[ -n "${line:-}" ]]; do
        [[ -z "${line:-}" || "$line" == \#* ]] && continue
        [[ "${line,,}" == "$want" ]] || continue
        [[ -n "$kpath" ]] || continue
        if [[ -f "${ROOT_PREFIX}${kpath}" ]]; then
            printf '%s\n' "${ROOT_PREFIX}${kpath}"
            return 0
        fi
        if [[ -f "$kpath" ]]; then
            printf '%s\n' "$kpath"
            return 0
        fi
    done <"$mapfile"
    return 1
}

REPO="$(_nds_git_ssh_extract_repo "$@" || true)"
KEY=""
if [[ -n "$REPO" ]]; then
    KEY="$(_nds_git_ssh_lookup_key "$REPO" || true)"
fi

extra=(
    -o BatchMode=yes
    -o StrictHostKeyChecking=accept-new
    -o IdentitiesOnly=yes
    -o ConnectTimeout=30
)

if [[ -n "$KEY" && -f "$KEY" ]]; then
    exec "$SSH_BIN" -i "$KEY" "${extra[@]}" "$@"
fi

# No mapping: fall through to bare ssh (public inputs / unmapped remotes).
# Private remotes are gated at install time by nds_git_verify_target_ro_access.
exec "$SSH_BIN" "${extra[@]}" "$@"
