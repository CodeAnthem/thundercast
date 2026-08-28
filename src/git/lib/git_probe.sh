#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git probe helpers (standalone)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-08-28
# Description:   Argument-driven public probe and clone (optional identity path)
# ==================================================================================================

# Description: GIT_SSH_COMMAND without any identity (anonymous probe).
nds_git_ssh_env_bare() {
    printf '%s\n' \
        "GIT_TERMINAL_PROMPT=0" \
        "GIT_SSH_COMMAND=ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 -o IdentitiesOnly=yes"
}

# Description: GIT_SSH_COMMAND offering every given private key (ssh -i … -i …).
# Arguments:
# - key_path: <String...> Private key paths (missing files skipped; none → bare)
nds_git_ssh_env_for_keys() {
    local key_path cmd="ssh"
    local any=false

    for key_path in "$@"; do
        [[ -f "$key_path" ]] || continue
        cmd+=" -i \"${key_path}\""
        any=true
    done
    if [[ "$any" != true ]]; then
        nds_git_ssh_env_bare
        return 0
    fi
    printf '%s\n' \
        "GIT_TERMINAL_PROMPT=0" \
        "GIT_SSH_COMMAND=${cmd} -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30"
}

# Description: GIT_SSH_COMMAND for an explicit private key path.
# Arguments:
# - key_path: <String> Private key path
nds_git_ssh_env_for_key() {
    nds_git_ssh_env_for_keys "$1"
}

# Description: True when a repo is reachable without SSH keys (public).
# Arguments:
# - url: <String> Git URL
# Returns:
# - <Bool> 0 when ls-remote succeeds without credentials
nds_git_probe_public() {
    local url="$1" ssh_url
    local -a envv=()

    ssh_url=$(_nds_git_url_toSsh "$url")
    while IFS= read -r line; do envv+=("$line"); done < <(nds_git_ssh_env_bare)
    if command -v timeout &>/dev/null; then
        timeout 8 env "${envv[@]}" git -c credential.helper= ls-remote "$ssh_url" &>/dev/null
    else
        env "${envv[@]}" git -c credential.helper= ls-remote "$ssh_url" &>/dev/null
    fi
}

# Description: Clone a repository with an optional explicit SSH identity.
# Arguments:
# - url:      <String> Git URL
# - dest:     <String> Destination directory
# - depth:    <Int|optional> Clone depth (default 1; 0 = full clone)
# - key_path: <String|optional> Private key path (bare SSH when empty)
# Returns:
# - <Bool> 0 on success
nds_git_clone_with_key() {
    local url="$1" dest="$2" depth="${3:-1}" key_path="${4:-}" ssh_url
    local -a envv=()

    ssh_url=$(_nds_git_url_toSsh "$url")
    if [[ -n "$key_path" ]]; then
        while IFS= read -r line; do envv+=("$line"); done < <(nds_git_ssh_env_for_key "$key_path")
    else
        while IFS= read -r line; do envv+=("$line"); done < <(nds_git_ssh_env_bare)
    fi

    if [[ "$depth" == "0" ]]; then
        env "${envv[@]}" git -c credential.helper= clone "$ssh_url" "$dest"
    else
        env "${envv[@]}" git -c credential.helper= clone --depth "$depth" "$ssh_url" "$dest"
    fi
}
