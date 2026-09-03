#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake git closure access
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-08-31
# Description:   Discover flake git inputs via flake utility; probe-clone / gh for remote roots
# ==================================================================================================

# Description: Session directory for the root flake shallow clone.
_nds_git_flake_probe_repo_dir() {
    printf '%s/flake_probe/repo\n' "${NDS_RUNTIME_DIR:-/tmp/nds}"
}

# Description: Shallow-clone root flake once per session (closure, disko, install staging).
# Arguments:
# - root_url: <String> Root flake git URL
# Returns:
# - <Bool> 0 on success
nds_git_clone_flake_probe() {
    local root_url="$1"
    local clone_dir norm_url err rc=0

    clone_dir="$(_nds_git_flake_probe_repo_dir)"
    norm_url=$(_nds_git_url_toSsh "$root_url")

    # Reuse in-memory probe when URL matches (or URL unset from an earlier step).
    if [[ -f "${NDS_FLAKE_PROBE_REPO:-}/flake.nix" ]]; then
        if [[ -z "${NDS_FLAKE_PROBE_REPO_URL:-}" || "${NDS_FLAKE_PROBE_REPO_URL}" == "$norm_url" ]]; then
            NDS_FLAKE_PROBE_REPO_URL="$norm_url"
            export NDS_FLAKE_PROBE_REPO NDS_FLAKE_PROBE_REPO_URL
            return 0
        fi
    fi
    # Reuse session clone dir on disk without requiring the URL env to still be set.
    if [[ -f "${clone_dir}/flake.nix" ]]; then
        if [[ -z "${NDS_FLAKE_PROBE_REPO_URL:-}" || "${NDS_FLAKE_PROBE_REPO_URL}" == "$norm_url" ]]; then
            NDS_FLAKE_PROBE_REPO="$clone_dir"
            NDS_FLAKE_PROBE_REPO_URL="$norm_url"
            export NDS_FLAKE_PROBE_REPO NDS_FLAKE_PROBE_REPO_URL
            return 0
        fi
    fi

    mkdir -p "$(dirname "$clone_dir")"
    rm -rf "$clone_dir"

    err=$(nds_git_env_pullTo "$root_url" "$clone_dir" 1 2>&1) || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        debug "flake probe clone failed: ${err}"
        rm -rf "$clone_dir"
        return 1
    fi
    if [[ ! -f "${clone_dir}/flake.nix" ]]; then
        debug "flake.nix missing after clone of ${root_url}"
        rm -rf "$clone_dir"
        return 1
    fi

    NDS_FLAKE_PROBE_REPO="$clone_dir"
    NDS_FLAKE_PROBE_REPO_URL="$norm_url"
    export NDS_FLAKE_PROBE_REPO NDS_FLAKE_PROBE_REPO_URL
    nds_install_log "git: flake repository cloned (${norm_url})"
    return 0
}

# Description: Collect unique git remote URLs from a flake directory (flake utility).
_nds_git_flake_collect_git_remote_urls() {
    local flake_root="$1" root_url="${2:-}"
    flake_listGitUrls "$flake_root" "$root_url"
}

# Description: Decode base64 from GitHub API content field into a file.
_nds_git_b64_decode_to_file() {
    local b64="$1" dest="$2"
    if printf '%s' "$b64" | tr -d '\n' | base64 -d > "$dest" 2>/dev/null \
        && [[ -s "$dest" ]]; then
        return 0
    fi
    if command -v openssl &>/dev/null \
        && printf '%s' "$b64" | tr -d '\n' | openssl base64 -d -A > "$dest" 2>/dev/null \
        && [[ -s "$dest" ]]; then
        return 0
    fi
    return 1
}

# Description: Fetch flake.lock via gh API when clone is unavailable.
# Arguments:
# - root_url:  <String> Root flake git URL
# - lock_dest: <String> Destination file path
# Returns:
# - <Bool> 0 on success
_nds_git_fetch_flake_lock_via_api() {
    local root_url="$1" lock_dest="$2"
    local ssh_url parsed host owner repo content
    local -a gh_cmd=()

    ssh_url=$(_nds_git_url_toSsh "$root_url")
    parsed=$(_nds_git_url_parse "$ssh_url") || return 1
    IFS=$'\t' read -r host owner repo <<< "$parsed"
    nds_git_host_is_github "$host" || return 1
    git_gh_session_active 2>/dev/null || return 1
    git_gh_ensure_cmd gh_cmd || return 1
    [[ ${#gh_cmd[@]} -gt 0 ]] || return 1

    content=$("${gh_cmd[@]}" api "repos/${owner}/${repo}/contents/flake.lock" \
        --jq -r '.content // empty' 2>/dev/null) || content=""
    [[ -n "$content" ]] || return 1
    mkdir -p "$(dirname "$lock_dest")"
    if _nds_git_b64_decode_to_file "$content" "$lock_dest"; then
        nds_install_log "git: flake.lock via gh API (${owner}/${repo})"
        return 0
    fi
    return 1
}

# Description: Collect git input URLs from a remote root flake.
_nds_git_flake_collect_git_remote_urls_from_root() {
    local root_url="$1"
    local probe_dir lock_dir

    probe_dir="${NDS_FLAKE_PROBE_REPO:-$(_nds_git_flake_probe_repo_dir)}"
    if [[ -f "${probe_dir}/flake.nix" ]]; then
        export NDS_GIT_FLAKE_LOCK_FILE="${probe_dir}/flake.lock"
        flake_listGitUrls "$probe_dir" "$root_url"
        return 0
    fi

    lock_dir="${NDS_RUNTIME_DIR:-/tmp}/flake_probe/api"
    mkdir -p "$lock_dir"
    if _nds_git_fetch_flake_lock_via_api "$root_url" "${lock_dir}/flake.lock"; then
        export NDS_GIT_FLAKE_LOCK_FILE="${lock_dir}/flake.lock"
        flake_listGitUrls "$lock_dir" "$root_url"
        return 0
    fi

    warn "Could not clone flake repository — only checking the root repository."
    nds_install_log "git: flake probe clone failed for closure scan"
    [[ -n "$root_url" ]] && _nds_git_url_toSsh "$root_url"
}
