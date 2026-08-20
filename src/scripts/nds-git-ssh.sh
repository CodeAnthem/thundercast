#!/usr/bin/env bash
# ==================================================================================================
# NDS - Repo-aware SSH for git+ssh (deploy keys)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-08 | Modified: 2026-07-08
# Description:   Pick IdentityFile from nds-git.map by owner/repo (stock github.com URLs).
#                Installed to /root/.ssh/nds-git-ssh; used via GIT_SSH_COMMAND.
# Map format:    owner/repo<TAB>/absolute/key/path   (lowercase owner/repo)
# Optional env:  NDS_GIT_SSH_ROOT — prefix for paths (e.g. /mnt during ISO verify)
# ==================================================================================================
set -euo pipefail

MAP="${NDS_GIT_SSH_MAP:-/root/.ssh/nds-git.map}"
ROOT_PREFIX="${NDS_GIT_SSH_ROOT:-}"
SSH_BIN="${NDS_GIT_SSH_BIN:-ssh}"

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
