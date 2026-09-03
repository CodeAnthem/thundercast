#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake probe (compose): session clone, disko detection, access verification
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-09-03
# ==================================================================================================

# Description: Shallow-clone a flake for probing; reuse the closure-phase clone when available.
# Arguments:
# - repo_url: <String> Git remote URL
# Returns:
# - <String> Flake root path (stdout)
nds_flake_probe_clone() {
    local repo_url="$1"
    local probe_dir="${NDS_FLAKE_PROBE_REPO:-}"

    if [[ -f "${probe_dir}/flake.nix" ]]; then
        debug "Reusing session flake clone: ${probe_dir}"
        printf '%s\n' "$probe_dir"
        return 0
    fi
    if ! nds_git_clone_flake_probe "$repo_url"; then
        error "Could not clone $repo_url for probe"
        return 1
    fi
    printf '%s\n' "${NDS_FLAKE_PROBE_REPO}"
    return 0
}

# Description: Set DISK_STRATEGY=flake when the host ships disko.nix and strategy is still nds.
# Arguments:
# - flake_root:   <String> Flake checkout root
# - host:         <String> nixosConfigurations name
# - host_dir_rel: <String|optional> Hosts prefix
nds_flake_apply_disko_strategy() {
    local flake_root="$1" host="$2" host_dir_rel="${3:-hosts/x86_64-linux}" current

    current="$(nds_cfg_get DISK_STRATEGY)"
    [[ "${current:-nds}" == "nds" ]] || return 0
    nds_requireUtility flake || return 1
    flake_hostHasDisko "$flake_root" "$host" "$host_dir_rel" || return 0

    info "Flake defines disko.nix for ${host} — switching DISK_STRATEGY to flake"
    nds_install_log "auto: DISK_STRATEGY=flake (flake has disko.nix)"
    nds_cfg_set DISK_STRATEGY "flake"
    return 0
}

# Description: Inspect the flake (local path or remote clone) and apply disko strategy. Best-effort.
nds_flake_detect_disko() {
    local host host_dir local_path repo_url probe_root
    host=$(nds_cfg_get "FLAKE_HOST")
    host_dir=$(nds_cfg_get "FLAKE_HOST_DIR")
    host_dir="${host_dir:-hosts/x86_64-linux}"
    local_path=$(nds_cfg_get "FLAKE_LOCAL_PATH")
    repo_url=$(nds_cfg_get "FLAKE_REPO_URL")

    if [[ -n "$local_path" ]]; then
        [[ -d "$local_path" ]] && nds_flake_apply_disko_strategy "$local_path" "$host" "$host_dir"
    elif [[ -n "$repo_url" ]]; then
        probe_root=$(nds_flake_probe_clone "$repo_url") || return 0
        nds_flake_apply_disko_strategy "$probe_root" "$host" "$host_dir"
    fi
    return 0
}

# Description: Prepare flake env and verify git access to the flake and all its inputs.
# Skips the re-probe when the gate already verified access this session.
# Arguments:
# - source: <String|optional> "remote" | "local" override for nds_flake_prepare
nds_flake_install_prepare_and_verify() {
    local source="${1:-}" local_path repo_url

    nds_flake_prepare "$source"
    repo_url="$(nds_cfg_get FLAKE_REPO_URL)"
    local_path="$(nds_cfg_get FLAKE_LOCAL_PATH)"

    if declare -f nds_git_access_verified &>/dev/null && nds_git_access_verified; then
        nds_install_log "git: access already verified this session — skip re-probe"
    else
        if [[ -n "$repo_url" ]]; then
            nds_app_actionManager_logic_callFeature nds_git_access_run \
                "FLAKE_REPO_URL=$repo_url" \
                read \
                "Clone the install flake and its private inputs." || return 1
        fi
        nds_install_ui_section_flake_access
        if [[ -n "$local_path" && -d "$local_path" ]]; then
            nds_git_ensure_flake_closure_access "$local_path" "$repo_url" || return 1
        elif [[ -n "$repo_url" ]]; then
            nds_git_ensure_flake_closure_access "" "$repo_url" || return 1
        fi
    fi

    nds_flake_detect_disko
    return 0
}
