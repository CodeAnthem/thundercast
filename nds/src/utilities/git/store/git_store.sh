#!/usr/bin/env bash
# ==================================================================================================
# Git utility - store core (safeUrl-keyed cache)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-29 | Modified: 2026-09-02
# ==================================================================================================

declare -gA _GIT_STORE=() # "${safeUrl}|field" → value
declare -ga _GIT_STORE_URLS=() # Indexed safeUrls (debug)

# Description: True when this safeUrl already has identity in the store.
# Arguments:
# - safeUrl: <String> Store key
# Returns:
# - <Bool> 0 when host is set
_git_store_hasIdentity() {
    local safeUrl="${1:-}"
    [[ -n "$safeUrl" && ${_GIT_STORE["${safeUrl}|host"]+_} ]]
}

# Description: Index a URL: register safeUrl mapping, store identity once, run
# plugins. New raw forms of an already-indexed identity only register in
# _GIT_SAFE_URLS. Store keys are always safeUrl — never raw URL.
# Arguments:
# - url: <String> Raw git URL or safeUrl
# Returns:
# - <Bool> 0 when the repo is in the store
git_store_index() {
    local url="$1"
    local safeUrl
    local -A id=()

    if [[ -z "$url" ]]; then
        err "URL is empty"
        return 1
    fi

    if git_store_safeUrlExists "$url"; then
        safeUrl=${ git_store_getSafeUrl "$url"; } || return 1
        _git_store_hasIdentity "$safeUrl" && return 0
    fi

    _git_url_tryParse id "$url" || return 1
    safeUrl=${ _git_store_setSafeUrl "$url" id; } || return 1

    # Same identity under a new raw form — mapping registered; skip plugins
    if _git_store_hasIdentity "$safeUrl"; then
        return 0
    fi

    _GIT_STORE["${safeUrl}|host"]="${id[host]}"
    _GIT_STORE["${safeUrl}|owner"]="${id[owner]}"
    _GIT_STORE["${safeUrl}|repoName"]="${id[repoName]}"
    _GIT_STORE["${safeUrl}|provider"]="${id[provider]}"
    _GIT_STORE_URLS+=("$safeUrl")

    _git_store_info_index "$safeUrl" || return 1
    _git_store_access_index "$safeUrl" || return 1
}

# Description: Read a stored field. Indexes the URL first when missing.
# Arguments:
# - url:   <String> Raw URL or safeUrl
# - field: <String>
# Returns:
# - <String> Field value, empty when unset (stdout)
# - <Bool> 0 when the URL could be indexed
git_store_get() {
    local url="$1"
    local field="$2"
    local safeUrl

    git_store_index "$url" || return 1
    safeUrl=${ git_store_getSafeUrl "$url"; } || return 1
    printf '%s' "${_GIT_STORE["${safeUrl}|${field}"]-}"
}

# Description: Write a stored field. Indexes (and registers raw→safe) first.
# Arguments:
# - url:   <String> Raw URL or safeUrl
# - field: <String>
# - value: <String>
git_store_set() {
    local url="$1"
    local field="$2"
    local value="$3"
    local safeUrl

    git_store_index "$url" || return 1
    safeUrl=${ git_store_getSafeUrl "$url"; } || return 1
    _GIT_STORE["${safeUrl}|${field}"]="$value"
}

# Description: Parse a boolean string to canonical true|false.
# True:  true t yes y on enable enabled 1
# False: false f no n off disable disabled 0
# Arguments:
# - value: <String>
# Returns:
# - <String> true|false (stdout)
# - <Bool> 0 when valid
_git_store_parseBool() {
    case "${1,,}" in
        true|t|yes|y|on|enable|enabled|1)
            printf '%s' "true"
            return 0
            ;;
        false|f|no|n|off|disable|disabled|0)
            printf '%s' "false"
            return 0
            ;;
        *)
            err "invalid boolean value: $1"
            return 1
            ;;
    esac
}

# Description: Env overlay prefix for hydrate/export (default GIT_REPO).
# Names: ${GIT_ENV_PREFIX}_<safeUrl>_<field>
: "${GIT_ENV_PREFIX:=GIT_REPO}"

# Description: Set the env overlay prefix used by hydrate/export helpers.
# Arguments:
# - prefix: <String> e.g. GIT_REPO or NDS_REPO
git_store_setEnvPrefix() {
    GIT_ENV_PREFIX="${1:-GIT_REPO}"
    export GIT_ENV_PREFIX
}

# Description: Build overlay env var name for a safeUrl field.
# Arguments:
# - safeUrl: <String>
# - field:   <String>
# Returns:
# - <String> Env name (stdout)
_git_store_envName() {
    local safeUrl="$1" field="$2"
    local prefix="${GIT_ENV_PREFIX:-GIT_REPO}"
    printf '%s' "${prefix}_${safeUrl}_${field}"
}

# Description: Overlay ${GIT_ENV_PREFIX}_<safeUrl>_<field> env onto stored fields.
# Only pass fields that are allowed to be env-overridden (e.g. keyPath,
# targetDir) — never needWrite, accessVerified, or isPrivate.
# Arguments:
# - safeUrl: <String> Indexed safeUrl (from index plugins)
# - fields:  <String...> Field names this plugin owns
_git_store_overlayEnv() {
    local safeUrl="$1"
    local field envn value
    shift

    for field in "$@"; do
        envn=${ _git_store_envName "$safeUrl" "$field"; }
        value="${!envn-}"
        if [[ -n "$value" ]]; then
            git_store_set "$safeUrl" "$field" "$value"
        fi
    done
}

# Description: Export one stored field back to the overlay env name.
# Arguments:
# - url:   <String> Raw URL or safeUrl
# - field: <String>
# Returns:
# - <Bool> 0 when exported
git_store_exportField() {
    local url="$1" field="$2" safeUrl value envn
    git_store_index "$url" || return 1
    safeUrl=${ git_store_getSafeUrl "$url"; } || return 1
    value=${ git_store_get "$url" "$field"; } || return 1
    [[ -n "$value" ]] || return 1
    envn=${ _git_store_envName "$safeUrl" "$field"; }
    export "${envn}=${value}"
}

# Description: Export allowed overlay fields for a URL from the store (current values).
# Arguments:
# - url:    <String> Raw URL or safeUrl
# - fields: <String...> default keyPath targetDir
# Returns:
# - <Bool> 0 when indexed
git_store_exportOverlayEnv() {
    local url="$1"
    shift
    local field
    local -a fields=("$@")
    ((${#fields[@]})) || fields=(keyPath targetDir)
    git_store_index "$url" || return 1
    for field in "${fields[@]}"; do
        git_store_exportField "$url" "$field" 2>/dev/null || true
    done
    return 0
}

# Description: Dump every stored field of every indexed URL to stderr.
git_store_debug() {
    local safeUrl key field https
    local -a fields=()

    printf 'GIT store GIT_WORKDIR=%s\n' "${GIT_WORKDIR:-}" >&2
    for safeUrl in "${_GIT_STORE_URLS[@]+"${_GIT_STORE_URLS[@]}"}"; do
        https=${ git_store_get "$safeUrl" urlHttps; }
        printf 'repo %s\n' "$https" >&2
        fields=()
        for key in "${!_GIT_STORE[@]}"; do
            [[ "$key" == "${safeUrl}|"* ]] || continue
            fields+=("${key#*|}")
        done
        if ((${#fields[@]})); then
            while IFS= read -r field; do
                printf '  %s=%s\n' "$field" "${_GIT_STORE["${safeUrl}|${field}"]-}" >&2
            done < <(printf '%s\n' "${fields[@]}" | sort)
        fi
    done
}
