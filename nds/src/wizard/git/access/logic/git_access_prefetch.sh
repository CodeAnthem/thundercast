#!/usr/bin/env bash
# ==================================================================================================
# NDS - Prefetch flake git lock inputs into the Nix store
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-31
# Description:   Fetch private git flake inputs with per-repo deploy keys (live ISO, no daemon SSH)
# ==================================================================================================

# Description: Prefetch one git flake lock input into the active Nix store.
# Arguments:
# - url:     <String> Git URL from flake.lock
# - rev:     <String> Locked git revision
# - narHash: <String|optional> Locked narHash (required for reproducible fetchTree)
# Returns:
# - <Bool> 0 on success
nds_git_nix_prefetch_git_input() {
    local url="$1" rev="$2" narHash="${3:-}"
    local fetch_url probe_url expr
    local -a envv=() store_args=()
    local rc=0 log="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
    local nix_config="experimental-features = nix-command flakes"

    [[ -n "$url" && -n "$rev" ]] || return 1
    [[ -n "$narHash" ]] || {
        error "flake.lock git input missing narHash: ${url}"
        return 1
    }

    fetch_url="${ flake_fetchTreeUrl "$url"; }"
    probe_url="${ _nds_git_url_toSsh "$url"; }"
    nds_git_env_syncKeyFromNds "$probe_url" 2>/dev/null || true
    while IFS= read -r line; do envv+=("$line"); done < <(_nds_git_ssh_env_for_url "$probe_url")
    mapfile -t store_args < <(_nds_install_nix_install_store_args 2>/dev/null || true)

    expr="builtins.fetchTree { type = \"git\"; url = \"${fetch_url}\"; rev = \"${rev}\"; narHash = \"${narHash}\"; }"

    {
        printf '\n=== Prefetch git input ===\n'
        printf 'url=%s rev=%s\n' "$fetch_url" "$rev"
    } >>"$log"

    if ! env NIX_CONFIG="$nix_config" "${envv[@]}" \
        nix build "${store_args[@]}" --no-link --print-out-paths --impure --expr "$expr" >>"$log" 2>&1; then
        rc=$?
        debug "nix prefetch failed for ${probe_url} (${rev})"
        return "$rc"
    fi
    nds_install_log "git: prefetched ${probe_url} (${rev:0:12})"
    return 0
}

# Description: Prefetch every git input in flake.lock (per-repo deploy key SSH).
# Arguments:
# - flake_root: <String> Flake directory containing flake.lock
# Returns:
# - <Bool> 0 on success
nds_git_prefetch_flake_closure() {
    local flake_root="$1"
    local lock_file="${flake_root}/flake.lock"
    local url rev narHash probe_url

    [[ -f "$lock_file" ]] || {
        debug "No flake.lock at ${flake_root} — skip git prefetch"
        return 0
    }

    while IFS=$'\t' read -r url rev narHash; do
        [[ -n "$url" && -n "$rev" ]] || continue
        probe_url="${ _nds_git_url_toSsh "$url"; }"
        if declare -f nds_step_exec &>/dev/null; then
            nds_step_exec "Prefetching ${probe_url}" \
                nds_git_nix_prefetch_git_input "$url" "$rev" "$narHash" || return 1
        else
            info "Prefetching ${probe_url}..."
            nds_git_nix_prefetch_git_input "$url" "$rev" "$narHash" || return 1
        fi
    done < <(flake_listLockGitEntries "$lock_file")

    nds_install_log "git: flake lock git inputs prefetched"
    return 0
}
