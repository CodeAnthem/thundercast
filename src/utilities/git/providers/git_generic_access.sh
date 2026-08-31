#!/usr/bin/env bash
# ==================================================================================================
# Git utility - generic provider access (dispatch: isPrivate, probe, prompt, deploy keys)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-29 | Modified: 2026-08-31
# ==================================================================================================

# Description: Anonymous ls-remote: success → public; failure → private (needs auth).
# Arguments:
# - safeUrl: <String> Indexed safeUrl
# Returns:
# - stdout true|false
git_generic_isPrivate() {
    local safeUrl="$1"
    if _git_generic_lsRemote "$safeUrl" ""; then
        printf '%s' "false"
        return 0
    fi
    printf '%s' "true"
    return 0
}

# Description: Probe ls-remote (and write via clone + dry-run push when needWrite).
# Sets accessVerified on success.
# Arguments:
# - safeUrl:  <String> Indexed safeUrl
# - key_path: <String|optional> Private key
# Returns:
# - <Bool> 0 when the probe meets needWrite
git_generic_probeWithKey() {
    local safeUrl="$1"
    local key_path="${2:-}"
    local dest isPrivate needWrite

    if _git_generic_lsRemote "$safeUrl" "$key_path"; then
        isPrivate=${ git_store_get "$safeUrl" isPrivate; }
        if [[ "$isPrivate" == "unknown" || -z "$isPrivate" ]]; then
            if [[ -z "$key_path" ]]; then
                git_store_set "$safeUrl" isPrivate "false"
            else
                git_store_set "$safeUrl" isPrivate "true"
            fi
        fi
    else
        err "ls-remote failed"
        return 1
    fi
    needWrite=${ git_store_get "$safeUrl" needWrite; }
    if [[ "$needWrite" != "true" ]]; then
        git_store_set "$safeUrl" accessVerified "true"
        return 0
    fi
    dest=${ git_store_getTargetDir "$safeUrl"; }
    if [[ ! -d "$dest/.git" ]]; then
        _git_generic_clone "$safeUrl" "$dest" "$key_path" || return 1
    fi
    if _git_generic_pushDir "$dest" "$key_path" "true"; then
        git_store_set "$safeUrl" accessVerified "true"
        return 0
    fi
    err "write probe failed"
    return 1
}

# Description: Generic forges have no deploy-key API.
# Arguments:
# - safeUrl: <String>
# Returns:
# - <Bool> always 1
git_generic_addDeployKey() {
    err "deploy keys unsupported for this provider"
    return 1
}

# Description: Generic forges have no deploy-key API.
# Arguments:
# - safeUrl: <String>
# Returns:
# - <Bool> always 1
git_generic_removeDeployKey() {
    err "deploy key remove unsupported for this provider"
    return 1
}

# Description: Apply a prompt choice (path / paste / generate) and probe.
# Arguments:
# - safeUrl: <String> Indexed safeUrl
# - choice:  <String> 1|2|3
# Returns:
# - <Bool> 0 when the probe succeeds
_git_generic_applyAccessChoice() {
    local safeUrl="$1"
    local choice="$2"
    local dest key_path display
    dest=${ git_store_getKeyPath "$safeUrl"; } || return 1
    display=${ git_store_getUrlHttps "$safeUrl"; }

    case "$choice" in
        1)
            key_path=${ git_helper_keys_prompt_enterKeyPath; } || return 1
            git_store_set "$safeUrl" keyPath "$key_path"
            ;;
        2)
            git_helper_keys_prompt_enterPrivateKey "$dest" || return 1
            git_store_set "$safeUrl" keyPath "$dest"
            ;;
        3)
            git_helper_keys_create "$dest" "git-key" || return 1
            git_store_set "$safeUrl" keyPath "$dest"
            git_helper_keys_prompt_showPublicKey "$dest"
            printf 'URL: %s\nPress Enter when the key is registered.\n' "$display" >&2
            read -r
            ;;
        *)
            err "invalid choice: $choice"
            return 1
            ;;
    esac
    key_path=${ git_store_get "$safeUrl" keyPath; }
    git_generic_probeWithKey "$safeUrl" "$key_path"
}

# Description: path / paste / generate. Interactive only.
# Arguments:
# - safeUrl: <String> Indexed safeUrl
# - reason:  <String|optional>
# Returns:
# - <Bool> 0 when access was satisfied
git_generic_promptAccess() {
    local safeUrl="$1"
    local reason="${2:-}"
    local choice display
    display=${ git_store_getUrlHttps "$safeUrl"; }
    if [[ -n "$reason" ]]; then
        printf '\nRepo %s needs access: %s\n' "$display" "$reason" >&2
    else
        printf '\nRepo %s needs access.\n' "$display" >&2
    fi
    printf '  1) Path to existing private key\n' >&2
    printf '  2) Paste private key\n' >&2
    printf '  3) Generate a new key (print public key; add it on the forge yourself)\n' >&2
    printf 'Choice [1-3]: ' >&2
    read -r choice
    _git_generic_applyAccessChoice "$safeUrl" "$choice"
}
