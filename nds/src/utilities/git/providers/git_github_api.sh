#!/usr/bin/env bash
# ==================================================================================================
# Git utility - GitHub CLI API helpers (keys / deploy / content)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-09-02
# Description:   NDS collision policy + thin wraps over git_gh_* API ops.
#                Title collision: pass overwrite|alternate|cancel (or GIT_GH_KEY_TITLE_COLLISION).
#                Empty collision when a title clash exists → return 41 (caller asks, then retries).
# ==================================================================================================

readonly GIT_GH_RC_TITLE_COLLISION=41

_git_gh_collision_mode() {
    local explicit="${1:-}"
    if [[ -n "$explicit" ]]; then
        printf '%s' "$explicit"
        return 0
    fi
    printf '%s' "${GIT_GH_KEY_TITLE_COLLISION:-${NDS_GH_KEY_TITLE_COLLISION:-${NDS_GIT_SSH_KEY_TITLE_COLLISION:-}}}"
}

# Description: Resolve alternate title or overwrite prep (no UI).
# Arguments:
# - title:     <Nameref> Desired title (may be rewritten for alternate)
# - collision: <String> overwrite|alternate|cancel
# - exists_fn: <String> Function title -> non-empty stdout if title taken
# Returns:
# - 0 ok; 41 if collision empty; 1 cancel/fail
_git_gh_apply_title_collision() {
    local -n _git_gh_title=$1
    local collision="$2"
    local exists_fn="$3"
    local suffix n=2

    collision="${ _git_gh_collision_mode "$collision"; }"
    if [[ -z "$collision" ]]; then
        return "$GIT_GH_RC_TITLE_COLLISION"
    fi
    case "$collision" in
        overwrite)
            return 0
            ;;
        alternate)
            while :; do
                suffix="${_git_gh_title}-${n}"
                if [[ -z "$("$exists_fn" "$suffix")" ]]; then
                    _git_gh_title="$suffix"
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

_git_gh_pubkey_line() {
    local pub_file="$1"
    if declare -f _git_gh_pubkey_line &>/dev/null; then
        _git_gh_pubkey_line "$pub_file"
        return
    fi
    awk '{print $1" "$2}' "$pub_file"
}

_git_gh_user_key_ids_by_title() {
    local title="$1"
    local -a gh_cmd=()

    git_gh_cmd gh_cmd || return 1
    "${gh_cmd[@]}" ssh-key list --json id,title --jq ".[] | select(.title==\"${title}\") | .id" 2>/dev/null
}

_git_gh_user_key_delete() {
    local id="$1"
    local -a gh_cmd=()

    git_gh_cmd gh_cmd || return 1
    "${gh_cmd[@]}" ssh-key delete "$id" 2>/dev/null
}

_git_gh_api_add_readonly_user_key() {
    local pub_file="$1" title="$2"
    local key_body payload err rc
    local -a gh_cmd=()

    git_gh_cmd gh_cmd || return 1
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

# Description: Register public key on the GitHub account (read-only).
# Arguments:
# - pub_file:   <String> Public key path
# - title:      <String> Key title
# - collision:  <String|optional> overwrite|alternate|cancel
# Returns:
# - 0 success; 41 title collision needs policy; 1 failure
git_gh_register_account_key() {
    local pub_file="$1"
    local title="$2"
    local collision="${3:-}"
    local id rc=0
    local -a gh_cmd=()

    [[ -f "$pub_file" ]] || return 1
    git_gh_cmd gh_cmd || return 1

    if git_gh_pubkey_on_user "$pub_file"; then
        if git_gh_pubkey_is_readonly "$pub_file"; then
            declare -f nds_install_log &>/dev/null \
                && nds_install_log "gh: account SSH key already present read-only"
            return 0
        fi
        error "SSH key already on GitHub as read/write"
        return 1
    fi

    if [[ -n "${ _git_gh_user_key_ids_by_title "$title"; }" ]]; then
        _git_gh_apply_title_collision title "$collision" _git_gh_user_key_ids_by_title
        rc=$?
        [[ "$rc" -eq 0 ]] || return "$rc"
        if git_gh_pubkey_on_user "$pub_file"; then
            git_gh_pubkey_is_readonly "$pub_file" && return 0
            error "SSH key on GitHub is read/write"
            return 1
        fi
    fi

    collision="${ _git_gh_collision_mode "$collision"; }"
    while IFS= read -r id; do
        [[ -n "$id" ]] || continue
        if [[ "$collision" == "overwrite" ]]; then
            _git_gh_user_key_delete "$id" || true
        fi
    done < <(_git_gh_user_key_ids_by_title "$title")

    if ! _git_gh_api_add_readonly_user_key "$pub_file" "$title"; then
        error "Could not add read-only SSH key to GitHub account"
        return 1
    fi

    if git_gh_ssh_key_is_readonly "$title" || git_gh_pubkey_is_readonly "$pub_file"; then
        declare -f nds_install_log &>/dev/null \
            && nds_install_log "gh: account SSH key added read-only (${title})"
        warn "Do not revoke GitHub CLI under Settings → Applications — GitHub would delete SSH keys this OAuth app created. ISO logout is enough."
        return 0
    fi

    error "GitHub registered the SSH key as read/write — read-only was requested"
    while IFS= read -r id; do
        [[ -n "$id" ]] || continue
        _git_gh_user_key_delete "$id" || true
    done < <(_git_gh_user_key_ids_by_title "$title")
    return 1
}

_git_gh_deploy_key_ids_by_title() {
    local owner="$1" repo="$2" title="$3"
    local -a gh_cmd=()

    git_gh_cmd gh_cmd || return 1
    git_gh_run 20 api "repos/${owner}/${repo}/keys" \
        --jq ".[] | select(.title==\"${title}\") | .id" 2>/dev/null
}

# Wrapper for apply_title_collision: exists_fn only gets title — bind owner/repo via globals.
_git_gh_deploy_title_taken() {
    local title="$1"
    _git_gh_deploy_key_ids_by_title "${_GIT_GH_DEPLOY_OWNER}" "${_GIT_GH_DEPLOY_REPO}" "$title"
}

_git_gh_deploy_key_delete() {
    local owner="$1" repo="$2" id="$3"
    local -a gh_cmd=()

    git_gh_cmd gh_cmd || return 1
    git_gh_run 20 api --method DELETE "repos/${owner}/${repo}/keys/${id}" 2>/dev/null
}

# Description: Add a deploy key to a repository via gh API.
# Arguments:
# - pub_file:  <String> Public key path
# - owner:     <String> Repository owner
# - repo:      <String> Repository name
# - title:     <String> Key title on GitHub
# - collision: <String|optional> overwrite|alternate|cancel
# - read_only: <String|optional> true (default) or false
# Returns:
# - 0 success; 41 title collision needs policy; 1 failure
git_gh_register_deploy_key() {
    local pub_file="$1" owner="$2" repo="$3" title="$4"
    local collision="${5:-}"
    local read_only="${6:-true}"
    local key_body payload err rc=0 id
    local -a gh_cmd=()

    [[ "$read_only" == "false" ]] || read_only="true"

    [[ -f "$pub_file" ]] || return 1
    [[ -n "$owner" && -n "$repo" && -n "$title" ]] || return 1
    git_gh_cmd gh_cmd || return 1

    debug "Checking existing deploy keys on ${owner}/${repo}..."
    if [[ -n "${ _git_gh_deploy_key_ids_by_title "$owner" "$repo" "$title"; }" ]]; then
        _GIT_GH_DEPLOY_OWNER="$owner"
        _GIT_GH_DEPLOY_REPO="$repo"
        _git_gh_apply_title_collision title "$collision" _git_gh_deploy_title_taken
        rc=$?
        unset _GIT_GH_DEPLOY_OWNER _GIT_GH_DEPLOY_REPO
        [[ "$rc" -eq 0 ]] || return "$rc"
    fi

    collision="${ _git_gh_collision_mode "$collision"; }"

    debug "Checking whether this public key is already registered..."
    if git_gh_deploy_pubkey_on_repo "$owner" "$repo" "$pub_file"; then
        declare -f nds_install_log &>/dev/null \
            && nds_install_log "gh: deploy key already on ${owner}/${repo} (${title})"
        git_gh_session_mark_scopes_ok
        return 0
    fi

    if [[ "$collision" == "overwrite" ]]; then
        debug "Removing existing deploy keys with title: ${title}"
        while IFS= read -r id; do
            [[ -n "$id" ]] || continue
            _git_gh_deploy_key_delete "$owner" "$repo" "$id" || true
        done < <(_git_gh_deploy_key_ids_by_title "$owner" "$repo" "$title")
        if git_gh_deploy_pubkey_on_repo "$owner" "$repo" "$pub_file"; then
            declare -f nds_install_log &>/dev/null \
                && nds_install_log "gh: deploy key already on ${owner}/${repo} (${title})"
            git_gh_session_mark_scopes_ok
            return 0
        fi
    fi

    key_body="$(tr -d '\n' < "$pub_file")"
    payload=$(printf '{"title":"%s","key":"%s","read_only":%s}' "$title" "$key_body" "$read_only")

    debug "Creating deploy key \"${title}\" on ${owner}/${repo}..."
    err=$(git_gh_run 30 api --method POST "repos/${owner}/${repo}/keys" \
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
            git_gh_session_mark_scopes_ok
            return 0
        fi
        error "GitHub API rejected deploy key on ${owner}/${repo}"
        return 1
    fi
    declare -f nds_install_log &>/dev/null \
        && nds_install_log "gh: deploy key added (read_only=${read_only}) on ${owner}/${repo} (${title})"
    git_gh_session_mark_scopes_ok
    return 0
}

