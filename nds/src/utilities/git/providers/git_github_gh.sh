#!/usr/bin/env bash
# ==================================================================================================
# Git utility - GitHub CLI wrappers (GH_BIN or PATH)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-29 | Modified: 2026-09-02
# ==================================================================================================

declare -gA _GIT_GH_ACCOUNTS=()

# Description: Mark host/owner of this URL as using gh for all its repos.
# Arguments:
# - url: <String> Raw URL or safeUrl
# Returns:
# - <Bool> 0 when the account was recorded
git_gh_setAccountUsingGh() {
    local url="$1"
    local acc
    acc=${ git_store_getAccountUID "$url"; } || return 1
    _GIT_GH_ACCOUNTS["$acc"]="true"
}

# Description: True when the account of this URL uses gh.
# Arguments:
# - url: <String> Raw URL or safeUrl
# Returns:
# - <Bool> 0 when useGh is true
git_gh_isAccountUsingGh() {
    local url="$1"
    local acc safe envn
    acc=${ git_store_getAccountUID "$url"; } || return 1
    if [[ "${_GIT_GH_ACCOUNTS[$acc]:-}" == "true" ]]; then
        return 0
    fi
    safe="${acc//[^A-Za-z0-9]/_}"
    envn="GIT_ACCOUNT_${safe}_useGh"
    [[ "${!envn:-}" == "true" ]]
}

# Description: Resolve gh binary (GH_BIN or PATH).
# Returns:
# - <String> Path or command (stdout)
# - <Bool> 0 when found
git_gh_bin() {
    if [[ -n "${GH_BIN:-}" && -x "${GH_BIN}" ]]; then
        printf '%s' "$GH_BIN"
        return 0
    fi
    if [[ -n "${NDS_GH_BIN:-}" && -x "${NDS_GH_BIN}" ]]; then
        printf '%s' "$NDS_GH_BIN"
        return 0
    fi
    command -v gh 2>/dev/null
}

# Description: True when gh is available.
# Returns:
# - <Bool> 0 when gh exists
git_gh_isAvailable() {
    git_gh_bin >/dev/null
}

# Description: True when gh reports a logged-in session.
# Returns:
# - <Bool> 0 when authenticated
git_gh_isAuthenticated() {
    local bin
    bin=${ git_gh_bin; } || return 1
    "$bin" auth status >/dev/null 2>&1
}

# Description: Interactive gh auth login.
# Returns:
# - <Bool> 0 on success
git_gh_login() {
    local bin
    bin=${ git_gh_bin; } || return 1
    "$bin" auth login
}

# Description: gh auth logout.
# Returns:
# - <Bool> 0 on success
git_gh_logout() {
    local bin
    bin=${ git_gh_bin; } || return 1
    "$bin" auth logout
}

# Description: True when gh reports the repo private.
# Arguments:
# - slug: <String> owner/name
# Returns:
# - 0 private, 1 public, 2 unknown (gh missing or view failed)
git_gh_isRepoPrivate() {
    local slug="$1" priv bin
    bin=${ git_gh_bin; } || return 2
    git_gh_isAuthenticated || return 2
    priv="$("$bin" repo view "$slug" --json isPrivate --jq .isPrivate 2>/dev/null)" || return 2
    [[ "$priv" == "true" ]]
}

# Description: gh repo clone into dest.
# Arguments:
# - slug: <String> owner/name
# - dest: <String>
# Returns:
# - <Bool> 0 on success
git_gh_clone() {
    local slug="$1" dest="$2" bin
    bin=${ git_gh_bin; } || return 1
    git_gh_isAuthenticated || return 1
    mkdir -p "$(dirname "$dest")"
    "$bin" repo clone "$slug" "$dest" -- --depth 1
}

# Description: Add a deploy key via gh.
# Arguments:
# - slug:     <String> owner/name
# - pub_file: <String> .pub path
# - title:    <String>
# - access:   <String> read|write
# Returns:
# - <Bool> 0 on success
git_gh_addDeployKey() {
    local slug="$1" pub_file="$2" title="$3" access="${4:-read}" bin
    local -a extra=()
    [[ -f "$pub_file" ]] || return 1
    bin=${ git_gh_bin; } || return 1
    git_gh_isAuthenticated || return 1
    [[ "$access" == "write" ]] && extra+=(--allow-write)
    "$bin" repo deploy-key add "$pub_file" --repo "$slug" --title "$title" "${extra[@]}"
}

# Description: Run gh args with an optional timeout (no UI).
# Arguments:
# - timeout_s: <Int> Seconds (0 = no timeout wrapper)
# - ...:       args after the gh binary
# Returns:
# - <Bool> Command exit status
git_gh_run() {
    local timeout_s="${1:-0}"
    shift
    local bin
    bin=${ git_gh_bin; } || return 1
    if [[ "$timeout_s" -gt 0 ]] && command -v timeout >/dev/null 2>&1; then
        timeout "${timeout_s}s" "$bin" "$@"
    else
        "$bin" "$@"
    fi
}

_git_gh_pubkey_line() {
    local pub_file="$1"
    awk '{print $1" "$2}' "$pub_file"
}

# Description: True when the public key is on the logged-in GitHub user.
# Arguments:
# - pub_file: <String> .pub path
# Returns:
# - <Bool> 0 when present
git_gh_pubkey_on_user() {
    local pub_file="$1" key_line bin
    [[ -f "$pub_file" ]] || return 1
    bin=${ git_gh_bin; } || return 1
    key_line="${ _git_gh_pubkey_line "$pub_file"; }"
    "$bin" ssh-key list --json key --jq '.[].key' 2>/dev/null \
        | grep -qF "$key_line"
}

# Description: True when this pubkey is on the account as read-only.
# Arguments:
# - pub_file: <String> .pub path
# Returns:
# - <Bool> 0 when read-only
git_gh_pubkey_is_readonly() {
    local pub_file="$1" key_line ro bin
    [[ -f "$pub_file" ]] || return 1
    bin=${ git_gh_bin; } || return 1
    key_line="${ _git_gh_pubkey_line "$pub_file"; }"
    ro=$("$bin" ssh-key list --json key,read_only \
        --jq ".[] | select(.key==\"${key_line}\") | .read_only" 2>/dev/null | head -1)
    [[ "$ro" == "true" ]]
}

# Description: True when a titled GitHub SSH key is marked read-only.
# Arguments:
# - title: <String>
# Returns:
# - <Bool> 0 when read-only
git_gh_ssh_key_is_readonly() {
    local title="$1" ro bin
    bin=${ git_gh_bin; } || return 1
    ro=$("$bin" ssh-key list --json title,read_only \
        --jq ".[] | select(.title==\"${title}\") | .read_only" 2>/dev/null | head -1)
    [[ "$ro" == "true" ]]
}

# Description: True when this pubkey is already a deploy key on owner/repo.
# Arguments:
# - owner:    <String>
# - repo:     <String>
# - pub_file: <String> .pub path
# Returns:
# - <Bool> 0 when present
git_gh_deploy_pubkey_on_repo() {
    local owner="$1" repo="$2" pub_file="$3" key_body
    [[ -f "$pub_file" ]] || return 1
    [[ -n "$owner" && -n "$repo" ]] || return 1
    key_body="$(awk '{print $2}' "$pub_file")"
    [[ -n "$key_body" ]] || return 1
    git_gh_run 20 api "repos/${owner}/${repo}/keys" --jq '.[].key' 2>/dev/null \
        | grep -qF "$key_body"
}

# Description: Fetch raw file content from a GitHub repo via Contents API.
# Arguments:
# - owner: <String>
# - repo:  <String>
# - path:  <String> File path in repo
# Returns:
# - decoded file body on stdout; 1 on failure
git_gh_repo_file_content() {
    local owner="$1" repo="$2" path="$3" content bin
    [[ -n "$owner" && -n "$repo" && -n "$path" ]] || return 1
    bin=${ git_gh_bin; } || return 1
    content=$("$bin" api "repos/${owner}/${repo}/contents/${path}" \
        --jq -r '.content // empty' 2>/dev/null) || return 1
    [[ -n "$content" ]] || return 1
    printf '%s' "$content" | tr -d '\n' | base64 -d
}

# Description: Record whether a leftover gh session existed at load.
# Returns:
# - <Bool> 0 after the lock file is written or skipped
git_gh_onLoad() {
    local lock="${GIT_WORKDIR:-}/gh.session"
    [[ -n "${GIT_WORKDIR:-}" ]] || return 0
    if git_gh_isAuthenticated; then
        printf '1\n' >"$lock"
    fi
}

# Description: Logout quietly when authenticated (never prompts).
# Returns:
# - <Bool> 0 after logout attempt or skip
git_gh_onExit() {
    git_gh_isAuthenticated || return 0
    git_gh_logout || true
}

# Description: Resolve gh into a nameref command array (no download).
# Arguments:
# - out: <Nameref> Command prefix array
git_gh_cmd() {
    local -n _git_gh_cmd_out=$1
    local bin
    bin=${ git_gh_bin; } || {
        _git_gh_cmd_out=()
        return 1
    }
    _git_gh_cmd_out=("$bin")
    return 0
}

# Description: Alias for callers expecting "available" naming.
git_gh_available() {
    git_gh_isAvailable
}
