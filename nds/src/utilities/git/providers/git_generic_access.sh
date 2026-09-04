#!/usr/bin/env bash
# ==================================================================================================
# Git utility - generic provider access (dispatch: isPrivate, probe, deploy keys)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-29 | Modified: 2026-09-04
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
        if declare -f nds_install_log &>/dev/null; then
            nds_install_log "git: ls-remote failed ${safeUrl}"
        elif declare -F debug &>/dev/null; then
            debug "ls-remote failed ${safeUrl}"
        fi
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
    if declare -f nds_install_log &>/dev/null; then
        nds_install_log "git: write probe failed ${safeUrl}"
    elif declare -F debug &>/dev/null; then
        debug "write probe failed ${safeUrl}"
    fi
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
