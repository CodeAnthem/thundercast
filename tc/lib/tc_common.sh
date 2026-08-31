#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast host CLI (tc) — common helpers (NDS-free)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-08-31
# ==================================================================================================

: "${TC_FLAKE_ROOT:=/etc/nixos}"
: "${TC_FLAKE_HOST:=$(hostname -s 2>/dev/null || echo nixos)}"
: "${TC_FLAKE_REF:=origin/main}"
: "${TC_BIN_DIR:=/root/.tc/bin}"
: "${TC_GIT_SSH_BIN:=ssh}"

tc_die() {
    printf 'tc: %s\n' "$*" >&2
    exit 1
}

tc_info() {
    printf 'tc: %s\n' "$*"
}

# Description: Default path to tc-git.map (owner/repo → key).
tc_git_map_path() {
    if [[ -n "${TC_GIT_SSH_MAP:-}" ]]; then
        printf '%s\n' "$TC_GIT_SSH_MAP"
        return 0
    fi
    local cand
    for cand in \
        "${HOME}/.ssh/tc-git.map" \
        "/root/.ssh/tc-git.map"
    do
        if [[ -f "$cand" ]]; then
            printf '%s\n' "$cand"
            return 0
        fi
    done
    printf '%s\n' "${HOME}/.ssh/tc-git.map"
}

# Description: Resolve tc-git-ssh executable for GIT_SSH_COMMAND.
tc_resolve_git_ssh() {
    local wrap="${TC_GIT_SSH_WRAPPER:-}"
    if [[ -n "$wrap" && -x "$wrap" ]]; then
        printf '%s\n' "$wrap"
        return 0
    fi
    if [[ -x "${TC_BIN_DIR}/tc-git-ssh" ]]; then
        printf '%s\n' "${TC_BIN_DIR}/tc-git-ssh"
        return 0
    fi
    if command -v tc-git-ssh &>/dev/null; then
        command -v tc-git-ssh
        return 0
    fi
    if [[ -x /root/.ssh/tc-git-ssh ]]; then
        printf '%s\n' /root/.ssh/tc-git-ssh
        return 0
    fi
    return 1
}
