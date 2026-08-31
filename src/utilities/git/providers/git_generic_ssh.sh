#!/usr/bin/env bash
# ==================================================================================================
# Git utility - generic provider SSH env helpers
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-29 | Modified: 2026-08-31
# ==================================================================================================

# Description: SSH env lines for anonymous git (no identity file).
# Arguments:
# - dest: <Nameref> Indexed array of NAME=value entries
_git_generic_sshEnvBare() {
    local -n _bareEnv="$1"
    _bareEnv=(
        "GIT_TERMINAL_PROMPT=0"
        "GIT_SSH_COMMAND=ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 -o IdentitiesOnly=yes"
    )
}

# Description: SSH env lines for an optional identity file.
# Arguments:
# - dest:     <Nameref> Indexed array of NAME=value entries
# - key_path: <String|optional> Private key
_git_generic_sshEnvForKey() {
    local destName="$1"
    local key_path="$2"
    local -n _keyEnv="$destName"

    if [[ -z "$key_path" || ! -f "$key_path" ]]; then
        _git_generic_sshEnvBare "$destName"
        return 0
    fi
    _keyEnv=(
        "GIT_TERMINAL_PROMPT=0"
        "GIT_SSH_COMMAND=ssh -i \"${key_path}\" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30"
    )
}

# Description: Run git with SSH env for an optional identity.
# Arguments:
# - key_path: <String|optional> Private key
# - ...:      git arguments after `git -c credential.helper=`
_git_generic_withEnv() {
    local key_path="${1:-}"
    shift
    local -a envv=()

    _git_generic_sshEnvForKey envv "$key_path"
    env "${envv[@]}" git -c credential.helper= "$@"
}
