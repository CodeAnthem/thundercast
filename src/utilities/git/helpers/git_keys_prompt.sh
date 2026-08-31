#!/usr/bin/env bash
# ==================================================================================================
# Git utility - key prompts (explicit; never called from api)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-29 | Modified: 2026-08-30
# ==================================================================================================

# Description: Ask for an existing private key path and validate it.
# Returns:
# - <String> Key path (stdout)
# - <Bool> 0 when the path is a usable key
git_helper_keys_prompt_enterKeyPath() {
    local path

    printf 'Key path: ' >&2
    read -r path
    [[ -f "$path" ]] || return 1
    git_helper_keys_isValid "$path" || return 1
    printf '%s' "$path"
}

# Description: Read a pasted private key (END sentinel) and write it to dest.
# Arguments:
# - dest: <String> Destination private key path
# Returns:
# - <Bool> 0 when written
git_helper_keys_prompt_enterPrivateKey() {
    local dest="$1" body="" line
    [[ -n "$dest" ]] || return 1
    printf 'Paste private key, then a line with only END\n' >&2
    while IFS= read -r line; do
        [[ "$line" == "END" ]] && break
        body+="$line"$'\n'
    done
    git_helper_keys_writeBody "$dest" "$body"
}

# Description: Print the public key for a private key path to stderr.
# Arguments:
# - path: <String> Private key file
# Returns:
# - <Bool> 0 when the public key was printed
git_helper_keys_prompt_showPublicKey() {
    local path="$1"
    local pub
    printf 'Public key:\n' >&2
    pub=${ git_helper_keys_getPublic "$path"; } || return 1
    printf '%s\n' "$pub" >&2
}
