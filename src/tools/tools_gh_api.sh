#!/usr/bin/env bash
# ==================================================================================================
# NDS - GitHub CLI API helpers (keys / deploy / content)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-17
# Description:   gh api operations — no git key paths, no settings menus.
#                Title collision: pass overwrite|alternate|cancel (or NDS_GH_KEY_TITLE_COLLISION).
#                Empty collision when a title clash exists → return 41 (caller asks, then retries).
# ==================================================================================================

readonly NDS_GH_RC_TITLE_COLLISION=41

# Description: Run gh api (or args) with a bounded timeout.
# Arguments:
# - timeout_s: <Int> Timeout seconds
# - ...:       command + args (usually from nds_gh_cmd)
nds_gh_api_with_timeout() {
    local timeout_s="$1"
    shift
    local -a cmd=("$@")

    [[ ${#cmd[@]} -gt 0 ]] || return 1
    if command -v timeout >/dev/null 2>&1; then
        timeout "${timeout_s}s" "${cmd[@]}"
    else
        "${cmd[@]}"
    fi
}

_nds_gh_collision_mode() {
    local explicit="${1:-}"
    if [[ -n "$explicit" ]]; then
        printf '%s' "$explicit"
        return 0
    fi
    printf '%s' "${NDS_GH_KEY_TITLE_COLLISION:-${NDS_GIT_SSH_KEY_TITLE_COLLISION:-}}"
}

# Description: Resolve alternate title or overwrite prep (no UI).
# Arguments:
# - title:     <Nameref> Desired title (may be rewritten for alternate)
# - collision: <String> overwrite|alternate|cancel
# - exists_fn: <String> Function title -> non-empty stdout if title taken
# Returns:
# - 0 ok; 41 if collision empty; 1 cancel/fail
_nds_gh_apply_title_collision() {
    local -n _nds_gh_title=$1
    local collision="$2"
    local exists_fn="$3"
    local suffix n=2

    collision="$(_nds_gh_collision_mode "$collision")"
    if [[ -z "$collision" ]]; then
        return "$NDS_GH_RC_TITLE_COLLISION"
    fi
    case "$collision" in
        overwrite)
            return 0
            ;;
        alternate)
            while :; do
                suffix="${_nds_gh_title}-${n}"
                if [[ -z "$("$exists_fn" "$suffix")" ]]; then
                    _nds_gh_title="$suffix"
                    return 0
                fi
                n=$((n + 1))
                [[ "$n" -gt 50 ]] && return 1
            done
            ;;
        *)
            return 1
            ;;
    esac
}

_nds_gh_pubkey_line() {
    local pub_file="$1"
    awk '{print $1" "$2}' "$pub_file"
}

_nds_gh_user_key_ids_by_title() {
    local title="$1"
    local -a gh_cmd=()

    nds_gh_cmd gh_cmd || return 1
    "${gh_cmd[@]}" ssh-key list --json id,title --jq ".[] | select(.title==\"${title}\") | .id" 2>/dev/null
}

_nds_gh_user_key_delete() {
    local id="$1"
    local -a gh_cmd=()

    nds_gh_cmd gh_cmd || return 1
    "${gh_cmd[@]}" ssh-key delete "$id" 2>/dev/null
}

_nds_gh_api_add_readonly_user_key() {
    local pub_file="$1" title="$2"
    local key_body payload err rc
    local -a gh_cmd=()

    nds_gh_cmd gh_cmd || return 1
    key_body="$(tr -d '\n' < "$pub_file")"
    payload=$(printf '{"title":"%s","key":"%s","read_only":true}' "$title" "$key_body")

    err=$("${gh_cmd[@]}" api --method POST user/keys \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        --input - <<< "$payload" 2>&1) || rc=$?
    if [[ "${rc:-0}" -ne 0 ]]; then
        debug "gh api POST user/keys failed: ${err}"
        return 1
    fi
    return 0
}

# Description: True when the public key is on the logged-in GitHub user account.
nds_gh_pubkey_on_user() {
    local pub_file="$1"
    local key_line
    local -a gh_cmd=()

    nds_gh_cmd gh_cmd || return 1
    key_line="$(_nds_gh_pubkey_line "$pub_file")"
    "${gh_cmd[@]}" ssh-key list --json key --jq '.[].key' 2>/dev/null \
        | grep -qF "$key_line"
}

# Description: True when this pubkey is already on the GitHub account as read-only.
nds_gh_pubkey_is_readonly() {
    local pub_file="$1"
    local key_line ro
    local -a gh_cmd=()

    nds_gh_cmd gh_cmd || return 1
    key_line="$(_nds_gh_pubkey_line "$pub_file")"
    ro=$("${gh_cmd[@]}" ssh-key list --json key,read_only \
        --jq ".[] | select(.key==\"${key_line}\") | .read_only" 2>/dev/null | head -1)
    [[ "$ro" == "true" ]]
}

# Description: True when a titled GitHub SSH key is marked read-only.
nds_gh_ssh_key_is_readonly() {
    local title="$1"
    local ro
    local -a gh_cmd=()

    nds_gh_cmd gh_cmd || return 1
    ro=$("${gh_cmd[@]}" ssh-key list --json title,read_only \
        --jq ".[] | select(.title==\"${title}\") | .read_only" 2>/dev/null | head -1)
    [[ "$ro" == "true" ]]
}

# Description: Register public key on the GitHub account (read-only).
# Arguments:
# - pub_file:   <String> Public key path
# - title:      <String> Key title
# - collision:  <String|optional> overwrite|alternate|cancel
# Returns:
# - 0 success; 41 title collision needs policy; 1 failure
nds_gh_register_account_key() {
    local pub_file="$1"
    local title="$2"
    local collision="${3:-}"
    local id rc=0
    local -a gh_cmd=()

    [[ -f "$pub_file" ]] || return 1
    nds_gh_cmd gh_cmd || return 1

    if nds_gh_pubkey_on_user "$pub_file"; then
        if nds_gh_pubkey_is_readonly "$pub_file"; then
            declare -f nds_install_log &>/dev/null \
                && nds_install_log "gh: account SSH key already present read-only"
            return 0
        fi
        error "SSH key already on GitHub as read/write"
        return 1
    fi

    if [[ -n "$(_nds_gh_user_key_ids_by_title "$title")" ]]; then
        _nds_gh_apply_title_collision title "$collision" _nds_gh_user_key_ids_by_title
        rc=$?
        [[ "$rc" -eq 0 ]] || return "$rc"
        if nds_gh_pubkey_on_user "$pub_file"; then
            nds_gh_pubkey_is_readonly "$pub_file" && return 0
            error "SSH key on GitHub is read/write"
            return 1
        fi
    fi

    collision="$(_nds_gh_collision_mode "$collision")"
    while IFS= read -r id; do
        [[ -n "$id" ]] || continue
        if [[ "$collision" == "overwrite" ]]; then
            _nds_gh_user_key_delete "$id" || true
        fi
    done < <(_nds_gh_user_key_ids_by_title "$title")

    if ! _nds_gh_api_add_readonly_user_key "$pub_file" "$title"; then
        error "Could not add read-only SSH key to GitHub account"
        return 1
    fi

    if nds_gh_ssh_key_is_readonly "$title" || nds_gh_pubkey_is_readonly "$pub_file"; then
        declare -f nds_install_log &>/dev/null \
            && nds_install_log "gh: account SSH key added read-only (${title})"
        return 0
    fi

    error "GitHub registered the SSH key as read/write — read-only was requested"
    while IFS= read -r id; do
        [[ -n "$id" ]] || continue
        _nds_gh_user_key_delete "$id" || true
    done < <(_nds_gh_user_key_ids_by_title "$title")
    return 1
}

_nds_gh_deploy_key_ids_by_title() {
    local owner="$1" repo="$2" title="$3"
    local -a gh_cmd=()

    nds_gh_cmd gh_cmd || return 1
    nds_gh_api_with_timeout 20 "${gh_cmd[@]}" api "repos/${owner}/${repo}/keys" \
        --jq ".[] | select(.title==\"${title}\") | .id" 2>/dev/null
}

# Wrapper for apply_title_collision: exists_fn only gets title — bind owner/repo via globals.
_nds_gh_deploy_title_taken() {
    local title="$1"
    _nds_gh_deploy_key_ids_by_title "${_NDS_GH_DEPLOY_OWNER}" "${_NDS_GH_DEPLOY_REPO}" "$title"
}

_nds_gh_deploy_key_delete() {
    local owner="$1" repo="$2" id="$3"
    local -a gh_cmd=()

    nds_gh_cmd gh_cmd || return 1
    nds_gh_api_with_timeout 20 "${gh_cmd[@]}" api --method DELETE "repos/${owner}/${repo}/keys/${id}" 2>/dev/null
}

# Description: True when this pubkey is already a deploy key on owner/repo.
nds_gh_deploy_pubkey_on_repo() {
    local owner="$1" repo="$2" pub_file="$3"
    local key_body
    local -a gh_cmd=()

    [[ -f "$pub_file" ]] || return 1
    nds_gh_cmd gh_cmd || return 1
    key_body="$(awk '{print $2}' "$pub_file")"
    [[ -n "$key_body" ]] || return 1
    nds_gh_api_with_timeout 20 "${gh_cmd[@]}" api "repos/${owner}/${repo}/keys" --jq '.[].key' 2>/dev/null \
        | grep -qF "$key_body"
}

# Description: Add a deploy key to a repository via gh API.
# read_only comes from NDS_GH_DEPLOY_READ_ONLY (default true). The install leaf
# uses false so remoteAction can push new hosts.
# Arguments:
# - pub_file:  <String> Public key path
# - owner:     <String> Repository owner
# - repo:      <String> Repository name
# - title:     <String> Key title on GitHub
# - collision: <String|optional> overwrite|alternate|cancel
# Returns:
# - 0 success; 41 title collision needs policy; 1 failure
nds_gh_register_deploy_key() {
    local pub_file="$1" owner="$2" repo="$3" title="$4"
    local collision="${5:-}"
    local key_body payload err rc=0 id
    local -a gh_cmd=()

    [[ -f "$pub_file" ]] || return 1
    [[ -n "$owner" && -n "$repo" && -n "$title" ]] || return 1
    nds_gh_cmd gh_cmd || return 1

    debug "Checking existing deploy keys on ${owner}/${repo}..."
    if [[ -n "$(_nds_gh_deploy_key_ids_by_title "$owner" "$repo" "$title")" ]]; then
        _NDS_GH_DEPLOY_OWNER="$owner"
        _NDS_GH_DEPLOY_REPO="$repo"
        _nds_gh_apply_title_collision title "$collision" _nds_gh_deploy_title_taken
        rc=$?
        unset _NDS_GH_DEPLOY_OWNER _NDS_GH_DEPLOY_REPO
        [[ "$rc" -eq 0 ]] || return "$rc"
    fi

    collision="$(_nds_gh_collision_mode "$collision")"

    debug "Checking whether this public key is already registered..."
    if nds_gh_deploy_pubkey_on_repo "$owner" "$repo" "$pub_file"; then
        declare -f nds_install_log &>/dev/null \
            && nds_install_log "gh: deploy key already on ${owner}/${repo} (${title})"
        nds_gh_session_mark_scopes_ok
        return 0
    fi

    if [[ "$collision" == "overwrite" ]]; then
        debug "Removing existing deploy keys with title: ${title}"
        while IFS= read -r id; do
            [[ -n "$id" ]] || continue
            _nds_gh_deploy_key_delete "$owner" "$repo" "$id" || true
        done < <(_nds_gh_deploy_key_ids_by_title "$owner" "$repo" "$title")
        if nds_gh_deploy_pubkey_on_repo "$owner" "$repo" "$pub_file"; then
            declare -f nds_install_log &>/dev/null \
                && nds_install_log "gh: deploy key already on ${owner}/${repo} (${title})"
            nds_gh_session_mark_scopes_ok
            return 0
        fi
    fi

    key_body="$(tr -d '\n' < "$pub_file")"
    payload=$(printf '{"title":"%s","key":"%s","read_only":%s}' "$title" "$key_body" "${NDS_GH_DEPLOY_READ_ONLY:-true}")

    debug "Creating deploy key \"${title}\" on ${owner}/${repo}..."
    err=$(nds_gh_api_with_timeout 30 "${gh_cmd[@]}" api --method POST "repos/${owner}/${repo}/keys" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        --input - <<< "$payload" 2>&1) || rc=$?
    if [[ "${rc:-0}" -ne 0 ]]; then
        debug "gh api POST repos/${owner}/${repo}/keys failed: ${err}"
        if grep -qi 'timed out' <<< "$err"; then
            error "GitHub API timed out while creating deploy key on ${owner}/${repo}"
            return 1
        fi
        if grep -qi 'already exists\|key is already in use' <<< "$err"; then
            declare -f nds_install_log &>/dev/null \
                && nds_install_log "gh: deploy key may already exist on ${owner}/${repo}"
            nds_gh_session_mark_scopes_ok
            return 0
        fi
        error "GitHub API rejected deploy key on ${owner}/${repo}"
        return 1
    fi
    declare -f nds_install_log &>/dev/null \
        && nds_install_log "gh: deploy key added (read_only=${NDS_GH_DEPLOY_READ_ONLY:-true}) on ${owner}/${repo} (${title})"
    nds_gh_session_mark_scopes_ok
    return 0
}

# Description: Fetch raw file content from a GitHub repo via Contents API.
# Arguments:
# - owner: <String>
# - repo:  <String>
# - path:  <String> File path in repo
# Returns:
# - decoded file body on stdout; 1 on failure
nds_gh_repo_file_content() {
    local owner="$1" repo="$2" path="$3"
    local content
    local -a gh_cmd=()

    [[ -n "$owner" && -n "$repo" && -n "$path" ]] || return 1
    nds_gh_cmd gh_cmd || return 1
    content=$("${gh_cmd[@]}" api "repos/${owner}/${repo}/contents/${path}" \
        --jq -r '.content // empty' 2>/dev/null) || return 1
    [[ -n "$content" ]] || return 1
    printf '%s' "$content" | tr -d '\n' | base64 -d
}

