#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH key management (session wiring)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-08-28
# Description:   NDS-aware paths and session wiring around git/lib key ops
# ==================================================================================================

_nds_git_host_label_from_cfg() {
    local name=""
    if declare -f nds_cfg_get &>/dev/null; then
        name="$(nds_cfg_get FLAKE_HOST 2>/dev/null || true)"
        [[ -z "$name" ]] && name="$(nds_cfg_get NETWORK_HOSTNAME 2>/dev/null || true)"
    fi
    [[ -z "$name" ]] && name="$(hostname -s 2>/dev/null || echo live)"
    printf '%s\n' "$name"
}

# Description: Owner slug from FLAKE_REPO_URL in settings.
# Returns:
# - <String> slug or "unknown"
nds_git_cfg_owner_slug() {
    local url=""
    if declare -f nds_cfg_get &>/dev/null; then
        url="$(nds_cfg_get FLAKE_REPO_URL 2>/dev/null || true)"
    fi
    nds_git_owner_slug "$url"
}

# Description: Active private git SSH key path for this NDS session (persists under /root/.ssh).
# Returns:
# - <String> Key file path (stdout)
nds_git_session_key_path() {
    local slug base

    if [[ -n "${NDS_GIT_SESSION_KEY_PATH:-}" ]]; then
        printf '%s\n' "$NDS_GIT_SESSION_KEY_PATH"
        return 0
    fi
    slug="$(nds_git_cfg_owner_slug)"
    if [[ "$slug" != "unknown" ]]; then
        base="$(nds_git_secrets_basename)"
        printf '/root/.ssh/%s\n' "$base"
    else
        printf '/root/.ssh/git-unknown-key\n'
    fi
}

# Description: Basename for owner-scoped git SSH key files (e.g. git-codeanthem-key).
# Returns:
# - <String> basename without directory (stdout)
nds_git_secrets_basename() {
    printf '%s\n' "$(nds_git_secrets_basename_from_owner_slug "$(nds_git_cfg_owner_slug)")"
}

# Description: Target install path relative to mount root.
# Returns:
# - <String> e.g. etc/nixos/secrets/git-codeanthem-key (stdout)
nds_git_target_key_rel() {
    printf 'etc/nixos/secrets/%s\n' "$(nds_git_secrets_basename)"
}

# Description: Absolute path on installed system.
# Returns:
# - <String> e.g. /etc/nixos/secrets/git-codeanthem-key (stdout)
nds_git_target_key_abs() {
    printf '/%s\n' "$(nds_git_target_key_rel)"
}

# Description: Public key path for the session git SSH key.
# Returns:
# - <String> .pub path (stdout)
nds_git_session_pubkey_path() {
    local key
    key="$(nds_git_session_key_path)"
    printf '%s\n' "${key}.pub"
}

# Description: SSH key title / ssh-keygen comment (owner + flake host when known).
# Returns:
# - <String> e.g. nds-codeanthem-control-toolkit
nds_git_ssh_key_title() {
    nds_git_session_key_title_for "$(nds_git_cfg_owner_slug)" "$(_nds_git_host_label_from_cfg)"
}

# Description: Copy a private key into place with safe permissions and load into ssh-agent.
# Arguments:
# - src:  <String> Source private key file
# - dest: <String|optional> Destination path (default session key path)
# Returns:
# - <Bool> 0 on success
nds_git_key_import() {
    local src="$1" dest="${2:-$(nds_git_session_key_path)}"
    nds_git_key_import_to "$src" "$dest"
}

# Description: Load a private key into ssh-agent (starts agent if needed).
# Arguments:
# - key_path: <String|optional> Private key path
# Returns:
# - <Bool> 0 on success
nds_git_key_load() {
    local key_path="${1:-$(nds_git_session_key_path)}"
    nds_git_key_load_path "$key_path"
}

# Description: Generate an ed25519 git SSH key pair (reuses existing file when present).
# Arguments:
# - dest:    <String|optional> Private key path
# - comment: <String|optional> Key comment (default nds-<owner>-<flake host>)
# Returns:
# - <Bool> 0 on success
nds_git_key_generate() {
    local dest="${1:-$(nds_git_session_key_path)}"
    local comment="${2:-$(nds_git_ssh_key_title)}"
    nds_git_key_generate_at "$dest" "$comment" "${NDS_GIT_KEY_FORCE_REGEN:-false}"
}

# Description: Load persisted session key from /root/.ssh when NDS restarts on the live ISO.
# Returns:
# - <Bool> 0 when an existing session key was loaded
nds_git_auth_try_session_key() {
    local dest

    dest="$(nds_git_session_key_path)"
    [[ -f "$dest" ]] || return 1
    nds_git_key_load "$dest" || return 1
    debug "Reused persisted git SSH key: ${dest}"
    return 0
}

# Description: Try loading NDS_GIT_IMPORT_KEY_PATH before interactive auth.
# Returns:
# - <Bool> 0 when key was imported and loaded
nds_git_auth_try_import_path() {
    local path="${NDS_GIT_IMPORT_KEY_PATH:-}"
    local dest
    [[ -n "$path" && -f "$path" ]] || return 1
    dest="$(nds_git_session_key_path)"
    if [[ "$path" == "$dest" ]]; then
        nds_git_key_load "$dest" || return 1
    else
        nds_git_key_import "$path" "$dest" || return 1
    fi
    debug "Loaded SSH key from import path"
    return 0
}

# Description: Destination for a pasted/imported key (deploy strategy → nds_deploy_*; else imported/session).
# Arguments:
# - url:      <String|optional> Git URL
# - strategy: <String|optional> GIT_ACCESS_STRATEGY (deploy-this / deploy-all → persist path)
# Returns:
# - <String> Private key path (stdout)
nds_git_key_dest_for_import() {
    local url="${1:-}" strategy="${2:-}"
    local parsed host owner repo

    if [[ -n "$url" ]] && parsed=$(_nds_git_url_parse "$url" 2>/dev/null); then
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        case "$strategy" in
            deploy-this|deploy-all)
                nds_git_deploy_key_path "$owner" "$repo"
                return 0
                ;;
        esac
        nds_git_imported_key_path "$owner" "$repo"
        return 0
    fi
    nds_git_session_key_path
}

# Description: Point a URL at a working key (copy to the per-repo deploy path when needed).
# Arguments:
# - key_path: <String> Private key that already passed ls-remote for this URL
# - url:      <String> Git URL
# Returns:
# - <Bool> 0 when the key is registered for that URL
nds_git_bind_key_to_url() {
    local key_path="$1" url="$2"
    local dest parsed host owner repo

    [[ -f "$key_path" ]] || return 1
    parsed=$(_nds_git_url_parse "$(_nds_git_url_toSsh "$url")" 2>/dev/null) || return 1
    IFS=$'\t' read -r host owner repo <<< "$parsed"
    dest="$(nds_git_deploy_key_path "$owner" "$repo")"
    if [[ "$key_path" != "$dest" ]]; then
        mkdir -p "$(dirname "$dest")"
        cp "$key_path" "$dest"
        chmod 600 "$dest"
        [[ -f "${key_path}.pub" ]] && cp "${key_path}.pub" "${dest}.pub"
        nds_git_keys_register "$dest" || true
        key_path="$dest"
    fi
    if declare -f nds_git_access_set &>/dev/null; then
        nds_git_access_set key_path "$url" "$key_path"
    fi
    return 0
}

# Description: Write key text to dest (default session path) and register it for this session.
# Arguments:
# - body: <String> PEM / OpenSSH private key text
# - dest: <String|optional> Destination path
# Returns:
# - <Bool> 0 on success
nds_git_key_import_body() {
    local body="$1" dest="${2:-$(nds_git_session_key_path)}"
    nds_git_key_write_body "$dest" "$body" || return 1
    nds_git_keys_register "$dest" || return 1
}

# Description: Try loading scalar NDS_GIT_IMPORT_KEY before interactive auth.
# Returns:
# - <Bool> 0 when key was written and loaded
nds_git_auth_try_import_body() {
    local body="${NDS_GIT_IMPORT_KEY:-}" dest
    [[ -n "$body" ]] || return 1
    dest="$(nds_git_session_key_path)"
    nds_git_key_import_body "$body" "$dest" || return 1
    debug "Loaded SSH key from NDS_GIT_IMPORT_KEY"
    return 0
}
