#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git naming utilities (standalone)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-08-15
# Description:   Slugs and basenames for git keys (argument-only; no NDS config)
# ==================================================================================================

_nds_git_slug_part() {
    local s="$1"
    s=$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')
    printf '%s' "$s" | sed -e 's/[^a-z0-9]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//'
}

_nds_git_deploy_slug_part() {
    local s="$1"
    s=$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')
    printf '%s' "$s" | sed -e 's/[^a-z0-9]/_/g' -e 's/__*/_/g' -e 's/^_//' -e 's/_$//'
}

# Description: Filesystem slug from owner and repo names.
# Arguments:
# - owner: <String> Git owner/org
# - repo:  <String> Repository name
# Returns:
# - <String> slug e.g. codeanthem-dps-swarm (stdout)
nds_git_repo_slug() {
    local owner="$1" repo="$2"
    printf '%s-%s\n' "$(_nds_git_slug_part "$owner")" "$(_nds_git_slug_part "$repo")"
}

# Description: Basename for a per-repo deploy key file.
# Arguments:
# - owner: <String> Git owner
# - repo:  <String> Repository name
# Returns:
# - <String> e.g. nds_deploy_codeanthem_thundercast (stdout)
nds_git_deploy_key_basename() {
    local owner="$1" repo="$2"
    printf 'nds_deploy_%s_%s' "$(_nds_git_deploy_slug_part "$owner")" "$(_nds_git_deploy_slug_part "$repo")"
}

# Description: Basename for a pasted/imported private key file (not copied on persist).
# Arguments:
# - owner: <String> Git owner
# - repo:  <String> Repository name
# Returns:
# - <String> e.g. nds_imported_codeanthem_thundercast (stdout)
nds_git_imported_key_basename() {
    local owner="$1" repo="$2"
    printf 'nds_imported_%s_%s' "$(_nds_git_deploy_slug_part "$owner")" "$(_nds_git_deploy_slug_part "$repo")"
}

# Description: owner/repo slug from a deploy key basename (nds_deploy_owner_repo).
# Arguments:
# - base: <String> Filename basename
# Returns:
# - <String> owner/repo (stdout) or non-zero when unparseable
nds_git_owner_repo_from_deploy_basename() {
    local base="$1" rest owner repo

    [[ "$base" == nds_deploy_* ]] || return 1
    rest="${base#nds_deploy_}"
    owner="${rest%%_*}"
    repo="${rest#*_}"
    [[ -n "$owner" && -n "$repo" && "$repo" != "$rest" ]] || return 1
    printf '%s/%s\n' "$owner" "$repo"
}

# Description: Sanitize a host label for key titles.
# Arguments:
# - name: <String> Raw host or machine name
# Returns:
# - <String> sanitized label (stdout)
nds_git_sanitize_host_label() {
    local name="$1"
    printf '%s' "$name" | sed -e 's/[^a-zA-Z0-9_-]/-/g' -e 's/--*/-/g'
}

# Description: Basename for owner-scoped git SSH key files.
# Arguments:
# - owner_slug: <String> Lowercase owner slug (e.g. codeanthem)
# Returns:
# - <String> basename without directory (stdout)
nds_git_secrets_basename_from_owner_slug() {
    local owner_slug="$1"
    printf 'git-%s-key\n' "$owner_slug"
}

# Description: SSH key title / ssh-keygen comment from owner slug and host label.
# Arguments:
# - owner_slug:  <String> Owner slug or "unknown"
# - host_label:  <String> Machine or flake host label
# Returns:
# - <String> e.g. nds-codeanthem-control-toolkit (stdout)
nds_git_session_key_title_for() {
    local owner_slug="$1" host_label="$2"

    host_label="$(nds_git_sanitize_host_label "$host_label")"
    if [[ "$owner_slug" != "unknown" && -n "$owner_slug" ]]; then
        printf 'nds-%s-%s' "$owner_slug" "$host_label"
    else
        printf 'nds-%s' "$host_label"
    fi
}

# Description: Deploy key title on GitHub from a host label.
# Arguments:
# - host_label: <String> Machine or flake host label
# Returns:
# - <String> title e.g. nds_control-toolkit (stdout)
nds_git_deploy_key_title_for() {
    local host_label="$1"
    printf 'nds_%s' "$(nds_git_sanitize_host_label "$host_label")"
}
