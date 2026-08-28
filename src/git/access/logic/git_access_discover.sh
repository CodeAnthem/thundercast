#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH key discovery (logic)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-28
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
    for f in "$dir"/id_* "$dir"/git-*-key "$dir"/deploy-* \
        "$dir"/nds_deploy_* "$dir"/nds_imported_* \
        "$dir"/*_ed25519 "$dir"/*_rsa; do
        [[ -f "$f" ]] || continue
        [[ "$f" == *.pub ]] && continue
        printf '%s\n' "$f"
    done
}

# Description: Register every private key in a directory (restore-bundle secrets/git).
# Arguments:
# - dir: <String> Directory to scan
nds_git_register_keys_in_dir() {
    local dir="$1" f

    [[ -d "$dir" ]] || return 0
    while IFS= read -r f; do
        [[ -f "$f" ]] || continue
        chmod 600 "$f" 2>/dev/null || true
        nds_git_keys_register "$f" || true
    done < <(_nds_git_discover_in_dir "$dir")
}

# Description: List private key candidates (cwd, then /root/.ssh).
# Returns:
# - <String> deduped paths (stdout)
nds_git_discover_key_candidates() {
    local owner_key import_path="${NDS_GIT_IMPORT_KEY_PATH:-}"
    owner_key="/root/.ssh/$(nds_git_secrets_basename)"
    {
        _nds_git_discover_in_dir "$PWD"
        _nds_git_discover_in_dir "/root/.ssh"
        [[ -f "$owner_key" ]] && printf '%s\n' "$owner_key"
        if [[ -n "$import_path" && -d "$import_path" ]]; then
            _nds_git_discover_in_dir "$import_path"
        elif [[ -n "$import_path" && -f "$import_path" ]]; then
            printf '%s\n' "$import_path"
            _nds_git_discover_in_dir "$(dirname "$import_path")"
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
        if declare -f nds_git_probe_access_with_key &>/dev/null; then
            nds_git_probe_access_with_key "$url" "$key_path" || return 1
        else
            nds_git_probe_access "$url" || return 1
        fi
        if declare -f nds_git_bind_key_to_url &>/dev/null; then
            nds_git_bind_key_to_url "$key_path" "$url" || true
        fi
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
