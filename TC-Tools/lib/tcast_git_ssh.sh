#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast host CLI — git-ssh (deploy-key map for GIT_SSH_COMMAND)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-08-31
# Description:   Pick IdentityFile from git.map by owner/repo.
# Map format:    owner/repo<TAB>/absolute/key/path   (lowercase owner/repo)
# Map path:      $TCAST_CONFIG_DIR/git.map (default /var/lib/tcast/git.map)
# Env:           TCAST_GIT_SSH_MAP, TCAST_GIT_SSH_ROOT (prefix for paths), TCAST_GIT_SSH_BIN
# ==================================================================================================

# Sourced from bin/tcast-git-ssh or `tcast git-ssh`. Expects tcast_common.sh already sourced.

tcast_git_ssh_init() {
    local repo="${1:-}" key="${2:-}"
    local map
    map="$(tcast_git_map_path)"
    mkdir -p "$(dirname "$map")"
    chmod 700 "$(dirname "$map")" 2>/dev/null || true
    if [[ -z "$repo" ]]; then
        if [[ -e /dev/tty ]]; then
            read -rp "owner/repo: " repo < /dev/tty
            read -rp "absolute path to SSH private key: " key < /dev/tty
        else
            tcast_die "usage: tcast git-ssh init owner/repo /absolute/path/to/key"
        fi
    fi
    repo="${repo,,}"
    repo="${repo%.git}"
    [[ "$repo" == */* ]] || tcast_die "expected owner/repo, got '${repo}'"
    [[ -n "$key" && "$key" == /* ]] || tcast_die "key path must be absolute"
    [[ -f "$key" ]] || tcast_info "warning: key file not found yet: ${key}"
    touch "$map"
    chmod 600 "$map"
    if grep -q "^${repo}"$'\t' "$map" 2>/dev/null; then
        tcast_info "${repo} already in ${map}"
        return 0
    fi
    printf '%s\t%s\n' "$repo" "$key" >>"$map"
    tcast_info "${repo} -> ${key} (${map})"
    tcast_info "Use:  export GIT_SSH_COMMAND=$(command -v tcast-git-ssh 2>/dev/null || echo tcast-git-ssh)"
}

_tcast_git_ssh_extract_repo() {
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

_tcast_git_ssh_lookup_key() {
    local want="$1" line kpath root_prefix="${TCAST_GIT_SSH_ROOT:-}"
    local map mapfile

    map="$(tcast_git_map_path)"
    mapfile="$map"
    [[ -f "${root_prefix}${map}" ]] && mapfile="${root_prefix}${map}"
    [[ -f "$mapfile" ]] || return 1

    while IFS=$'\t' read -r line kpath || [[ -n "${line:-}" ]]; do
        [[ -z "${line:-}" || "$line" == \#* ]] && continue
        [[ "${line,,}" == "$want" ]] || continue
        [[ -n "$kpath" ]] || continue
        if [[ -f "${root_prefix}${kpath}" ]]; then
            printf '%s\n' "${root_prefix}${kpath}"
            return 0
        fi
        if [[ -f "$kpath" ]]; then
            printf '%s\n' "$kpath"
            return 0
        fi
    done <"$mapfile"
    return 1
}

# Description: SSH wrapper entry (exec). Args are forwarded to ssh.
tcast_git_ssh_exec() {
    local repo key
    local -a extra

    if [[ "${1:-}" == init || "${1:-}" == --init ]]; then
        shift
        tcast_git_ssh_init "$@"
        return $?
    fi

    repo="$(_tcast_git_ssh_extract_repo "$@" || true)"
    key=""
    if [[ -n "$repo" ]]; then
        key="$(_tcast_git_ssh_lookup_key "$repo" || true)"
    fi

    extra=(
        -o BatchMode=yes
        -o StrictHostKeyChecking=accept-new
        -o IdentitiesOnly=yes
        -o ConnectTimeout=30
    )

    if [[ -n "$key" && -f "$key" ]]; then
        exec "${TCAST_GIT_SSH_BIN}" -i "$key" "${extra[@]}" "$@"
    fi
    exec "${TCAST_GIT_SSH_BIN}" "${extra[@]}" "$@"
}
