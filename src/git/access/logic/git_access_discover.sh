#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH key discovery (logic)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

# Description: Collect private key candidate paths from a directory.
# Arguments:
# - dir: <String> Directory to scan
# Returns:
# - <String> candidate paths (stdout)
_nds_git_discover_in_dir() {
    local dir="$1"
    local f base

    [[ -d "$dir" ]] || return 0
    for f in "$dir"/id_* "$dir"/git-*-key "$dir"/deploy-* "$dir"/*_ed25519 "$dir"/*_rsa; do
        [[ -f "$f" ]] || continue
        [[ "$f" == *.pub ]] && continue
        printf '%s\n' "$f"
    done
}

# Description: List private key candidates (cwd, then /root/.ssh).
# Returns:
# - <String> deduped paths (stdout)
nds_git_discover_key_candidates() {
    local owner_key
    owner_key="/root/.ssh/$(nds_git_secrets_basename)"
    {
        _nds_git_discover_in_dir "$PWD"
        _nds_git_discover_in_dir "/root/.ssh"
        [[ -f "$owner_key" ]] && printf '%s\n' "$owner_key"
        if [[ -n "${NDS_GIT_IMPORT_KEY_PATH:-}" && -f "${NDS_GIT_IMPORT_KEY_PATH}" ]]; then
            printf '%s\n' "${NDS_GIT_IMPORT_KEY_PATH}"
        elif [[ -n "${NDS_DEPLOY_KEY_PATH:-}" && -f "${NDS_DEPLOY_KEY_PATH}" ]]; then
            printf '%s\n' "${NDS_DEPLOY_KEY_PATH}"
        fi
    } | awk 'NF' | sort -u
}

# Description: Probe URLs with a candidate private key (loads into session registry).
# Arguments:
# - key_path: <String> Private key path
# - urls:     <String...> Git URLs to probe
# Returns:
# - <Bool> 0 when all URLs are reachable
nds_git_discover_probe_urls() {
    local key_path="$1"
    shift
    local -a urls=("$@")
    local url

    [[ -f "$key_path" ]] || return 1
    nds_git_keys_register "$key_path" || return 1

    for url in "${urls[@]}"; do
        [[ -n "$url" ]] || continue
        nds_git_probe_access "$url" || return 1
    done
    return 0
}

# Description: Try discovered keys against probe URLs.
# Arguments:
# - urls: <String...> Git URLs to probe
# Returns:
# - <String> winning key path on stdout, non-zero when none worked
nds_git_discover_try_candidates() {
    local -a urls=("$@")
    local candidate

    while IFS= read -r candidate; do
        [[ -n "$candidate" ]] || continue
        if nds_git_discover_probe_urls "$candidate" "${urls[@]}"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done < <(nds_git_discover_key_candidates)
    return 1
}
