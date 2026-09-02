#!/usr/bin/env bash
# ==================================================================================================
# Git utility - SSH ed25519 key material
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-29 | Modified: 2026-08-30
# ==================================================================================================

# Description: True when text looks like a PEM/OpenSSH private key body.
# Arguments:
# - body: <String> Key text
# Returns:
# - <Bool> 0 when markers are present
_git_helper_keys_bodyLooksValid() {
    local body="$1"
    [[ "$body" == *"BEGIN"* && "$body" == *"PRIVATE KEY"* && "$body" == *"END"* ]]
}

# Description: True when path is a usable OpenSSH private key.
# Arguments:
# - path: <String> Private key file
# Returns:
# - <Bool> 0 when ssh-keygen can read it
git_helper_keys_isValid() {
    local path="$1"
    [[ -f "$path" ]] || return 1
    ssh-keygen -y -f "$path" >/dev/null 2>&1
}

# Description: Public key line from a private key path.
# Arguments:
# - path: <String> Private key file
# Returns:
# - <String> Public key line (stdout)
# - <Bool> 0 when derived
git_helper_keys_getPublic() {
    local path="$1"
    local pub
    [[ -f "$path" ]] || return 1
    pub="$(ssh-keygen -y -f "$path" 2>/dev/null)" || return 1
    printf '%s' "$pub"
}

# Description: Fingerprint of a key file.
# Arguments:
# - path: <String> Private or public key file
# Returns:
# - <String> Fingerprint line (stdout)
# - <Bool> 0 when derived
git_helper_keys_getFingerprint() {
    local path="$1"
    local fp
    [[ -f "$path" ]] || return 1
    fp="$(ssh-keygen -lf "$path" 2>/dev/null)" || return 1
    printf '%s' "$fp"
}

# Description: Write private-key text to dest (0600) and derive .pub.
# Arguments:
# - dest: <String> Destination private key path
# - body: <String> OpenSSH/PEM private key text
# Returns:
# - <Bool> 0 when written
git_helper_keys_writeBody() {
    local dest="$1" body="$2"

    [[ -n "$dest" && -n "$body" ]] || return 1
    body="${body//$'\r'/}"
    _git_helper_keys_bodyLooksValid "$body" || return 1
    mkdir -p "$(dirname "$dest")"
    chmod 700 "$(dirname "$dest")" 2>/dev/null || true
    printf '%s' "$body" >"$dest"
    [[ "$body" == *$'\n' ]] || printf '\n' >>"$dest"
    chmod 600 "$dest"
    if ! ssh-keygen -y -f "$dest" >"${dest}.pub" 2>/dev/null; then
        rm -f "$dest" "${dest}.pub"
        return 1
    fi
    chmod 644 "${dest}.pub" 2>/dev/null || true
}

# Description: Generate ed25519 pair at dest (empty passphrase).
# Arguments:
# - dest:    <String> Private key path
# - comment: <String|optional> ssh-keygen -C
# Returns:
# - <Bool> 0 when created
git_helper_keys_create() {
    local dest="$1" comment="${2:-utility-git}"

    [[ -n "$dest" ]] || return 1
    mkdir -p "$(dirname "$dest")"
    chmod 700 "$(dirname "$dest")" 2>/dev/null || true
    rm -f "$dest" "${dest}.pub"
    ssh-keygen -t ed25519 -N "" -f "$dest" -C "$comment" >/dev/null 2>&1 || return 1
    chmod 600 "$dest"
}
