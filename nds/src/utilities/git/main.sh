#!/usr/bin/env bash
# ==================================================================================================
# Git utility - entry (define hooks only; sourcing does no work)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-29 | Modified: 2026-08-31
# ==================================================================================================

if (( BASH_VERSINFO[0] < 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] < 3) )); then
    printf 'GIT: requires Bash 5.3 or newer (found %s).\n' "${BASH_VERSION}" >&2
    return 1 2>/dev/null || exit 1
fi

# Use NDS error() when loaded under NDS; otherwise a GIT-prefixed fallback.
if ! declare -F error >/dev/null 2>&1; then
    error() {
        printf 'GIT: %s\n' "$1" >&2
    }
fi

# Prefix with calling function name. Do not redefine err inside functions —
# bash function defs are global and nested calls would clobber each other.
if ! declare -F err >/dev/null 2>&1; then
    err() {
        error "${FUNCNAME[1]:-git}: $1"
    }
fi

_GIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Description: Source every *.sh in a directory (order does not matter; calls
# resolve at runtime).
# Arguments:
# - dir: <String> Absolute directory path
_git_source_dir() {
    local dir="$1"
    local f
    for f in "$dir"/*.sh; do
        [[ -f "$f" ]] || continue
        # shellcheck disable=SC1090
        source "$f"
    done
}

_git_source_dir "${_GIT_DIR}/helpers"
_git_source_dir "${_GIT_DIR}/store"
_git_source_dir "${_GIT_DIR}/providers"

# Description: Create workdir. No SM, no NDS.
# Returns:
# - <Bool> 0 after workdir exists
git_onLoad() {
    GIT_WORKDIR="${GIT_WORKDIR:-${TMPDIR:-/tmp}/git_util.$$}"
    export GIT_WORKDIR
    mkdir -p "${GIT_WORKDIR}/git_repo" "${GIT_WORKDIR}/keys" || {
        err "failed to create GIT_WORKDIR"
        return 1
    }
    git_gh_onLoad
}

# Description: Wipe clones; gh session per interactive / auto-logout rules.
# Returns:
# - <Bool> 0 after cleanup
git_onExit() {
    git_gh_onExit
    if [[ -n "${GIT_WORKDIR:-}" && -d "$GIT_WORKDIR" ]]; then
        rm -rf "${GIT_WORKDIR}/git_repo"
    fi
}
