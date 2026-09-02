#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH env builders (standalone)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-09-01
# Description:   Argument-driven GIT_SSH_COMMAND lines for multi-key probes
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
