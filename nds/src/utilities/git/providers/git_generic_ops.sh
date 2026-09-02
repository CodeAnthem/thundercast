#!/usr/bin/env bash
# ==================================================================================================
# Git utility - generic provider remote ops
# Dispatch ops: git_generic_pull, git_generic_push
# Internal:     _git_generic_lsRemote, _clone, _fetch, _pushDir
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-29 | Modified: 2026-08-31
# ==================================================================================================

# Description: ls-remote with optional identity (no prompt).
# Arguments:
# - safeUrl:  <String> Indexed safeUrl
# - key_path: <String|optional> Private key
# Returns:
# - <Bool> 0 when the remote is reachable
_git_generic_lsRemote() {
    local safeUrl="$1" key_path="${2:-}" ssh_url
    ssh_url=${ git_store_getUrlSsh "$safeUrl"; } || return 1
    _git_generic_withEnv "$key_path" ls-remote "$ssh_url" >/dev/null 2>&1
}

# Description: Clone safeUrl into dest with optional identity.
# Arguments:
# - safeUrl:  <String> Indexed safeUrl
# - dest:     <String>
# - key_path: <String|optional>
# Returns:
# - <Bool> 0 on success
_git_generic_clone() {
    local safeUrl="$1" dest="$2" key_path="${3:-}" ssh_url
    ssh_url=${ git_store_getUrlSsh "$safeUrl"; } || return 1
    mkdir -p "$(dirname "$dest")"
    _git_generic_withEnv "$key_path" clone --depth 1 "$ssh_url" "$dest" || {
        err "clone failed: $ssh_url"
        return 1
    }
}

# Description: git fetch in an existing clone.
# Arguments:
# - dest:     <String> Clone directory
# - key_path: <String|optional>
# Returns:
# - <Bool> 0 on success
_git_generic_fetch() {
    local dest="$1" key_path="${2:-}"
    [[ -d "$dest/.git" || -f "$dest/HEAD" ]] || {
        err "not a git clone: $dest"
        return 1
    }
    _git_generic_withEnv "$key_path" -C "$dest" fetch
}

# Description: git push in a clone directory (optional --dry-run).
# Arguments:
# - dest:     <String> Clone directory
# - key_path: <String|optional>
# - dry_run:  <String|optional> true → --dry-run
# Returns:
# - <Bool> 0 on success (or dry-run without auth denial)
_git_generic_pushDir() {
    local dest="$1" key_path="${2:-}" dry_run="${3:-false}"
    local pushErr rc=0
    [[ -d "$dest" ]] || {
        err "missing clone dir: $dest"
        return 1
    }
    if [[ "$dry_run" == "true" ]]; then
        pushErr="${ _git_generic_withEnv "$key_path" -C "$dest" push --dry-run 2>&1; }" || rc=$?
        if printf '%s' "$pushErr" | grep -qiE 'denied|forbidden|authentication|permission'; then
            err "push dry-run denied"
            return 1
        fi
        return 0
    fi
    _git_generic_withEnv "$key_path" -C "$dest" push
}

# Description: Fetch an existing clone or clone the remote (dispatch op).
# Arguments:
# - safeUrl: <String> Indexed safeUrl
# Returns:
# - <Bool> 0 on success
git_generic_pull() {
    local safeUrl="$1"
    local dest key_path
    dest=${ git_store_getTargetDir "$safeUrl"; } || return 1
    key_path=${ git_store_get "$safeUrl" keyPath; }
    if [[ -d "$dest/.git" ]]; then
        _git_generic_fetch "$dest" "$key_path"
        return $?
    fi
    _git_generic_clone "$safeUrl" "$dest" "$key_path"
}

# Description: Push the clone for a safeUrl (dispatch op).
# Arguments:
# - safeUrl: <String> Indexed safeUrl
# Returns:
# - <Bool> 0 on success
git_generic_push() {
    local safeUrl="$1"
    local dest key_path
    dest=${ git_store_getTargetDir "$safeUrl"; } || return 1
    key_path=${ git_store_get "$safeUrl" keyPath; }
    _git_generic_pushDir "$dest" "$key_path" "false"
}
