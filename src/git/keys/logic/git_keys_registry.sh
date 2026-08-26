#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH key registry (session list, paths, titles)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-26
# Description:   Registry file listing session private key paths (one per line)
# ==================================================================================================

_nds_git_keys_registry_file() {
    printf '%s/git_session_keys\n' "${NDS_RUNTIME_DIR:-/tmp/nds}"
}

# Description: Register a private key path for this NDS session.
# Arguments:
# - key_path: <String> Private key file
nds_git_keys_register() {
    local key_path="$1"
    local reg

    [[ -f "$key_path" ]] || return 1
    reg="$(_nds_git_keys_registry_file)"
    mkdir -p "$(dirname "$reg")"
    if [[ -f "$reg" ]] && grep -qxF "$key_path" "$reg" 2>/dev/null; then
        return 0
    fi
    printf '%s\n' "$key_path" >> "$reg"
    nds_git_key_load "$key_path" || true
    nds_git_ssh_config_refresh || true
    return 0
}

# Description: List registered session private key paths.
# Returns:
# - <String> paths (stdout, one per line)
nds_git_keys_list() {
    local reg key_path

    {
        reg="$(_nds_git_keys_registry_file)"
        if [[ -f "$reg" ]]; then
            while IFS= read -r key_path; do
                [[ -f "$key_path" ]] && printf '%s\n' "$key_path"
            done < "$reg"
        fi
        key_path="$(nds_git_session_key_path 2>/dev/null || true)"
        if [[ -n "$key_path" && -f "$key_path" ]]; then
            printf '%s\n' "$key_path"
        fi
    } | awk 'NF' | sort -u
}

# Description: Load all registered keys into ssh-agent.
nds_git_keys_load_all() {
    local key_path

    while IFS= read -r key_path; do
        [[ -n "$key_path" && -f "$key_path" ]] || continue
        nds_git_key_load "$key_path" || true
    done < <(nds_git_keys_list)
}

# Description: Persist auth mode for closure behaviour (deploy|account|imported).
# Arguments:
# - mode: <String> deploy, account, or imported
nds_git_auth_set_mode() {
    local mode="$1"
    export NDS_GIT_AUTH_MODE="$mode"
    nds_cfg_set GIT_AUTH_MODE "$mode"
}

# Description: Current git auth mode (deploy, account, imported, or empty).
# Returns:
# - <String> mode (stdout)
nds_git_auth_mode() {
    local mode="${NDS_GIT_AUTH_MODE:-}"
    [[ -n "$mode" ]] || mode="$(nds_cfg_get GIT_AUTH_MODE 2>/dev/null || true)"
    printf '%s\n' "$mode"
}

# Description: Deploy key title on GitHub (nds_<flake-host> — one name per machine).
# Arguments:
# - owner: <String> Ignored (kept for call-site compatibility)
# - repo:  <String> Ignored
# Returns:
# - <String> title e.g. nds_control-toolkit (stdout)
nds_git_deploy_key_title() {
    nds_git_deploy_key_title_for "$(_nds_git_host_label_from_cfg)"
}

# Description: GitHub deploy-key title for this call (appends _write when the key must push).
# Arguments:
# - owner:     <String> Ignored (kept for call-site compatibility)
# - repo:      <String> Ignored
# - read_only: <String> true (default) or false
# Returns:
# - <String> title e.g. nds_control-toolkit or nds_control-toolkit_write (stdout)
nds_git_deploy_key_register_title() {
    local read_only="${3:-true}"
    local title
    title="$(nds_git_deploy_key_title "$1" "$2")"
    if [[ "$read_only" == "false" ]]; then
        printf '%s_write\n' "$title"
    else
        printf '%s\n' "$title"
    fi
}

# Description: Session path for a per-repo deploy private key.
# Arguments:
# - owner: <String> Git owner
# - repo:  <String> Repository name
# Returns:
# - <String> path under /root/.ssh (stdout)
nds_git_deploy_key_path() {
    local owner="$1" repo="$2" base="${NDS_GIT_DEPLOY_KEYS_DIR:-/root/.ssh}"
    printf '%s/%s\n' "$base" "$(nds_git_deploy_key_basename "$owner" "$repo")"
}

# Description: Session path for a pasted/imported private key (install-time unless persist copies nds_deploy_*).
# Arguments:
# - owner: <String> Git owner
# - repo:  <String> Repository name
# Returns:
# - <String> path under /root/.ssh (stdout)
nds_git_imported_key_path() {
    local owner="$1" repo="$2" base="${NDS_GIT_DEPLOY_KEYS_DIR:-/root/.ssh}"
    printf '%s/%s\n' "$base" "$(nds_git_imported_key_basename "$owner" "$repo")"
}

# Description: Target install path relative to mount root for a deploy key.
# Arguments:
# - owner: <String> Git owner
# - repo:  <String> Repository name
# Returns:
# - <String> e.g. root/.ssh/nds_deploy_codeanthem_thundercast (stdout)
nds_git_deploy_key_target_rel() {
    local owner="$1" repo="$2"
    printf 'root/.ssh/%s\n' "$(nds_git_deploy_key_basename "$owner" "$repo")"
}

# Description: Public key path for a per-repo deploy key.
# Arguments:
# - owner: <String> Git owner
# - repo:  <String> Repository name
# Returns:
# - <String> .pub path (stdout)
nds_git_deploy_key_pubkey_path() {
    printf '%s.pub\n' "$(nds_git_deploy_key_path "$1" "$2")"
}

# Description: Generate or reuse a deploy key for one repository.
# Arguments:
# - owner: <String> Git owner
# - repo:  <String> Repository name
# Returns:
# - <Bool> 0 on success
nds_git_deploy_key_generate() {
    local owner="$1" repo="$2"
    local dest title

    dest="$(nds_git_deploy_key_path "$owner" "$repo")"
    title="$(nds_git_deploy_key_title "$owner" "$repo")"
    nds_git_key_generate "$dest" "$title" || return 1
    nds_git_keys_register "$dest" || return 1
    nds_git_auth_set_mode deploy
    return 0
}

# Description: List deploy private key paths (session registry + nds_deploy_* on disk).
# Returns:
# - <String> paths (stdout, one per line)
_nds_git_collect_deploy_key_paths() {
    local deploy_dir="${NDS_GIT_DEPLOY_KEYS_DIR:-/root/.ssh}"
    local key_path

    {
        while IFS= read -r key_path; do
            [[ -f "$key_path" ]] && printf '%s\n' "$key_path"
        done < <(nds_git_keys_list 2>/dev/null || true)

        if [[ -d "$deploy_dir" ]]; then
            for key_path in "${deploy_dir}"/nds_deploy_*; do
                [[ -f "$key_path" ]] || continue
                [[ "$key_path" == *.pub ]] && continue
                printf '%s\n' "$key_path"
            done
        fi
    } | awk 'NF' | sort -u
}

# Description: Normalize persist-access to true|false, or empty when unset/unknown.
# Accepts GIT_PERSIST_ACCESS / NDS_GIT_PERSIST_ACCESS values: true|yes|1 / false|no|0.
_nds_git_persist_normalize() {
    local v="${1:-}"
    v="${v,,}"
    case "$v" in
        true|yes|1) printf 'true' ;;
        false|no|0) printf 'false' ;;
        *) printf '' ;;
    esac
}

# Description: True when the installed machine should keep private-git SSH access.
# Default true when unset. Reads CONFIG_DATA then NDS_GIT_PERSIST_ACCESS.
nds_git_persist_access() {
    local v
    v="$(nds_cfg_get GIT_PERSIST_ACCESS 2>/dev/null || true)"
    [[ -z "$v" ]] && v="${NDS_GIT_PERSIST_ACCESS:-}"
    v="$(_nds_git_persist_normalize "$v")"
    [[ -z "$v" || "$v" == "true" ]]
}
