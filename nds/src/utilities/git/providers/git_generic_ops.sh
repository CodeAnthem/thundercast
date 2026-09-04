#!/usr/bin/env bash
# ==================================================================================================
# Git utility - generic provider remote ops
# Dispatch ops: git_generic_pull, git_generic_push
# Internal:     _git_generic_lsRemote, _clone, _fetch, _pushDir
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-29 | Modified: 2026-09-04
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
    local safeUrl="$1" dest="$2" key_path="${3:-}" ssh_url log rc
    ssh_url=${ git_store_getUrlSsh "$safeUrl"; } || return 1
    log="${NDS_INSTALL_DETAIL_LOG:-}"
    [[ -n "$log" ]] || log="${NDS_INSTALL_LOG:-}"
    mkdir -p "$(dirname "$dest")"
    if [[ -n "$log" ]]; then
        {
            printf '\n=== git clone %s -> %s ===\n' "$ssh_url" "$dest"
            _git_generic_withEnv "$key_path" clone --quiet --depth 1 "$ssh_url" "$dest"
        } >>"$log" 2>&1
        rc=$?
    else
        _git_generic_withEnv "$key_path" clone --quiet --depth 1 "$ssh_url" "$dest" >/dev/null 2>&1
        rc=$?
    fi
    if [[ "$rc" -ne 0 ]]; then
        if declare -f nds_install_log &>/dev/null; then
            nds_install_log "git: clone failed ${ssh_url}"
        elif declare -F debug &>/dev/null; then
            debug "clone failed: ${ssh_url}"
        fi
        return 1
    fi
}

# Description: git fetch in an existing clone.
# Arguments:
# - dest:     <String> Clone directory
# - key_path: <String|optional>
# Returns:
# - <Bool> 0 on success
_git_generic_fetch() {
    local dest="$1" key_path="${2:-}" log rc
    [[ -d "$dest/.git" || -f "$dest/HEAD" ]] || {
        if declare -f nds_install_log &>/dev/null; then
            nds_install_log "git: not a git clone: ${dest}"
        elif declare -F debug &>/dev/null; then
            debug "not a git clone: ${dest}"
        fi
        return 1
    }
    log="${NDS_INSTALL_DETAIL_LOG:-}"
    [[ -n "$log" ]] || log="${NDS_INSTALL_LOG:-}"
    if [[ -n "$log" ]]; then
        {
            printf '\n=== git fetch %s ===\n' "$dest"
            _git_generic_withEnv "$key_path" -C "$dest" fetch --quiet
        } >>"$log" 2>&1
        rc=$?
    else
        _git_generic_withEnv "$key_path" -C "$dest" fetch --quiet >/dev/null 2>&1
        rc=$?
    fi
    return "$rc"
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
