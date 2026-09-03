#!/usr/bin/env bash
# ==================================================================================================
# NDS realize - flake staging steps (checkout on target disk, git index for eval)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-09-03
# ==================================================================================================

# Description: Put the flake at install_path: copy local dir, reuse the session probe clone,
# or shallow-clone with the NDS key. Existing .git checkout is kept.
# Arguments:
# - source:       <String> remote | local
# - local_path:   <String> Local flake directory (source=local)
# - repo_url:     <String> Git URL (source=remote)
# - install_path: <String> Destination on the target disk
_nds_realize_stage_flake() {
    local source="$1" local_path="$2" repo_url="$3" install_path="$4"
    local probe norm_url

    [[ -n "$install_path" ]] || { error "Flake install path is required"; return 1; }
    mkdir -p "$(dirname "$install_path")"

    if [[ "$source" == "local" ]]; then
        [[ -n "$local_path" && -d "$local_path" ]] || { error "Local flake path not found: ${local_path}"; return 1; }
        rm -rf "$install_path"
        cp -a "$local_path" "$install_path" || { error "Failed to copy flake to ${install_path}"; return 1; }
        nds_install_log "flake: staged local ${local_path} -> ${install_path}"
        return 0
    fi

    [[ -n "$repo_url" ]] || { error "FLAKE_REPO_URL is required for remote flake source"; return 1; }
    [[ -d "${install_path}/.git" ]] && return 0

    probe="${NDS_FLAKE_PROBE_REPO:-}"
    norm_url=$(_nds_git_url_toSsh "$repo_url")
    if [[ -n "$probe" && -f "${probe}/flake.nix" && "${NDS_FLAKE_PROBE_REPO_URL:-}" == "$norm_url" ]]; then
        rm -rf "$install_path"
        cp -a "$probe" "$install_path" || return 1
        nds_install_log "flake: staged from session clone -> ${install_path}"
        return 0
    fi

    rm -rf "$install_path"
    nds_git_env_pullTo "$repo_url" "$install_path" 1 || { error "Failed to stage ${repo_url} to ${install_path}"; return 1; }
    nds_install_log "flake: cloned ${repo_url} -> ${install_path}"
    return 0
}

# Description: git add committed host structure + gitignored facts so nix eval sees both.
# Arguments:
# - flake_root: <String> Flake checkout root
# - host_dir:   <String> Host directory
_nds_realize_flake_git_stage() {
    local flake_root="$1" host_dir="$2"
    local -a committed=() facts=()

    mapfile -t committed < <(flake_committedHostNames)
    mapfile -t facts < <(flake_hostFactNames)
    flake_gitStageHostFiles "$flake_root" "$host_dir" "${committed[@]}" || return 1
    flake_gitStageHostFiles "$flake_root" "$host_dir" "${facts[@]}" || return 1
    return 0
}
