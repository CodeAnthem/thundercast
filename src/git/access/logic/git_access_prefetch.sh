#!/usr/bin/env bash
# ==================================================================================================
# NDS - Prefetch flake git lock inputs into the Nix store
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-16
# Description:   Fetch private git flake inputs with per-repo deploy keys (live ISO, no daemon SSH)
# ==================================================================================================

# Description: List git lock nodes as url<TAB>rev<TAB>narHash (stdout).
# Arguments:
# - lock_file: <String> Path to flake.lock
_nds_git_flake_lock_git_entries() {
    local lock_file="$1"
    local lock_quoted entries

    [[ -f "$lock_file" ]] || return 0
    if command -v jq &>/dev/null; then
        entries=$(jq -r '
            .nodes[]?.locked?
            | select(.type == "git" and .url != null and .rev != null)
            | [.url, .rev, (.narHash // "")] | @tsv
        ' "$lock_file" 2>/dev/null || true)
    elif command -v nix &>/dev/null; then
        printf -v lock_quoted '%q' "$lock_file"
        entries=$(nix eval --impure --raw --expr "
            let
              lock = builtins.fromJSON (builtins.readFile ${lock_quoted});
              nodes = lock.nodes or {};
              names = builtins.attrNames nodes;
              line = name:
                let l = nodes.\${name}.locked or {};
                in if l.type or \"\" == \"git\" && l ? url && l ? rev
                   then l.url + \"\t\" + l.rev + \"\t\" + (l.narHash or \"\")
                   else \"\";
            in builtins.concatStringsSep \"\n\" (map line names)
        " 2>/dev/null || true)
    else
        warn "jq and nix unavailable — cannot prefetch git flake inputs from flake.lock"
        return 1
    fi
    printf '%s\n' "$entries" | awk -F'\t' 'NF >= 2 && !seen[$1 "\t" $2]++'
}

# Description: URL field for builtins.fetchTree (keep ssh:// from flake.lock).
# Arguments:
# - url: <String> Git URL from flake.lock
_nds_git_fetchtree_url() {
    local url="$1"

    case "$url" in
        git+ssh://*) printf '%s\n' "${url#git+ssh://}" ;;
        ssh://*) printf '%s\n' "$url" ;;
        git@*:*/*)
            local hostpath="${url#git@}"
            hostpath="${hostpath/:/\/}"
            printf 'ssh://git@%s\n' "$hostpath"
            ;;
        *) printf '%s\n' "$(_nds_git_url_toSsh "$url")" ;;
    esac
}

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

    fetch_url="$(_nds_git_fetchtree_url "$url")"
    probe_url="$(_nds_git_url_toSsh "$url")"
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
        probe_url="$(_nds_git_url_toSsh "$url")"
        if declare -f nds_step_exec &>/dev/null; then
            nds_step_exec "Prefetching ${probe_url}" \
                nds_git_nix_prefetch_git_input "$url" "$rev" "$narHash" || return 1
        else
            info "Prefetching ${probe_url}..."
            nds_git_nix_prefetch_git_input "$url" "$rev" "$narHash" || return 1
        fi
    done < <(_nds_git_flake_lock_git_entries "$lock_file")

    nds_install_log "git: flake lock git inputs prefetched"
    return 0
}
