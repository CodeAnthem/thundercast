#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git per-repo access state (URL-keyed maps)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-31 | Modified: 2026-08-16
# Description:   URL-keyed METHOD / KEY_PATH / KEY_KIND / EXISTING_KEY / KEY_MODE / KEY_BODY
# ==================================================================================================

# URL-keyed maps. Declared here (git feature load), not at settings-manager
# bootstrap, so they cannot wipe scalar NDS_* env during startup.
# KEY_BODY is session-only (never restore-exported).
# KEY_MODE is paste | path | gh | generate. EXISTING_KEY is true | false.
declare -gA NDS_GIT_METHOD=()
declare -gA NDS_GIT_KEY_PATH=()
declare -gA NDS_GIT_KEY_KIND=()
declare -gA NDS_GIT_EXISTING_KEY=()
declare -gA NDS_GIT_KEY_MODE=()
declare -gA NDS_GIT_KEY_BODY=()

# Description: Normalize a git URL to canonical SSH form for map keys.
# Arguments:
# - url: <String> Any git URL
# Returns:
# - <String> Normalized SSH URL (stdout)
nds_git_normalize_url() {
    local url="$1" parsed host owner repo
    [[ -n "$url" ]] || return 1
    if parsed=${ _nds_git_url_parse "$url" 2>/dev/null; }; then
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        _nds_git_url_formatSsh "$host" "$owner" "$repo"
        return 0
    fi
    _nds_git_url_toSsh "$url" 2>/dev/null || printf '%s\n' "$url"
}

# Description: Read a URL-keyed access map value.
# Arguments:
# - map: method | key_path | key_kind | existing_key | key_mode
nds_git_access_get() {
    local map="$1" url v=""
    url="${ nds_git_normalize_url "$2"; }" || return 1
    case "$map" in
        method)   printf '%s\n' "${NDS_GIT_METHOD[$url]:-}" ;;
        key_path) printf '%s\n' "${NDS_GIT_KEY_PATH[$url]:-}" ;;
        key_kind) printf '%s\n' "${NDS_GIT_KEY_KIND[$url]:-}" ;;
        existing_key)
            v="${NDS_GIT_EXISTING_KEY[$url]:-}"
            if [[ -z "$v" ]]; then
                case "${NDS_GIT_KEY_MODE[$url]:-${NDS_GIT_METHOD[$url]:-}}" in
                    paste|path|import) v="true" ;;
                    gh|generate) v="false" ;;
                esac
            fi
            printf '%s\n' "$v"
            ;;
        key_mode)
            v="${NDS_GIT_KEY_MODE[$url]:-}"
            if [[ -z "$v" ]]; then
                case "${NDS_GIT_METHOD[$url]:-}" in
                    paste|path|gh|generate) v="${NDS_GIT_METHOD[$url]}" ;;
                esac
            fi
            printf '%s\n' "$v"
            ;;
        *) return 1 ;;
    esac
}

# Description: Write a URL-keyed access map value.
# Arguments:
# - map: method | key_path | key_kind | existing_key | key_mode
nds_git_access_set() {
    local map="$1" value="$3" url
    url="${ nds_git_normalize_url "$2"; }" || return 1
    case "$map" in
        method)        NDS_GIT_METHOD["$url"]="$value" ;;
        key_path)      NDS_GIT_KEY_PATH["$url"]="$value" ;;
        key_kind)      NDS_GIT_KEY_KIND["$url"]="$value" ;;
        existing_key)  NDS_GIT_EXISTING_KEY["$url"]="$value" ;;
        key_mode)      NDS_GIT_KEY_MODE["$url"]="$value" ;;
        *) return 1 ;;
    esac
}

# Description: True when the URL map says to prompt (paste / path / gh / generate).
_nds_git_access_has_prompt_mode() {
    local mode
    mode="${ nds_git_access_get key_mode "$1" 2>/dev/null || true; }"
    [[ "$mode" == "paste" || "$mode" == "path" || "$mode" == "gh" || "$mode" == "generate" ]]
}

# Description: Materialize a map entry — write KEY_BODY if set, else register KEY_PATH.
# Arguments:
# - url: <String> Git URL
# Returns:
# - <Bool> 0 when a key file is registered
nds_git_access_materialize_key() {
    local url="$1" norm path body dest
    norm="${ nds_git_normalize_url "$url"; }" || return 1
    path="${NDS_GIT_KEY_PATH[$norm]:-}"
    body="${NDS_GIT_KEY_BODY[$norm]:-}"

    if [[ -n "$body" ]]; then
        dest="$path"
        [[ -n "$dest" ]] || dest="${ nds_git_key_dest_for_import "$norm"; }"
        nds_git_key_write_body "$dest" "$body" || return 1
        nds_git_keys_register "$dest" || return 1
        NDS_GIT_KEY_PATH["$norm"]="$dest"
        return 0
    fi

    if [[ -n "$path" && -f "$path" ]]; then
        nds_git_keys_register "$path" || return 1
        return 0
    fi
    return 1
}

# Description: Apply a stored map entry — materialize key if present and probe.
nds_git_access_apply_map() {
    local url="$1" norm
    norm="${ nds_git_normalize_url "$url"; }" || return 1

    [[ -n "${NDS_GIT_METHOD[$norm]:-}" || -n "${NDS_GIT_KEY_PATH[$norm]:-}" \
        || -n "${NDS_GIT_KEY_BODY[$norm]:-}" ]] || return 1

    nds_git_access_materialize_key "$url" || return 1
    nds_git_probe_access "$norm"
}
