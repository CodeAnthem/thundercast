#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake gate logic (no TTY; AA via nds_cfg_* bind or store)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# Description:   Normalize flake location, unattended target checks, ensure access
# ==================================================================================================

# Description: Normalize loc into FLAKE_* keys (URL vs local path).
nds_flake_gate_logic_normalize_location() {
    local loc="$1" src
    [[ -n "$loc" ]] || return 1
    src=$(nds_detect_flake_source "$loc")
    nds_cfg_set FLAKE_LOCATION "$loc"
    nds_cfg_set FLAKE_SOURCE "$src"
    if [[ "$src" == remote ]]; then
        nds_cfg_set FLAKE_REPO_URL "$loc"
        nds_cfg_set FLAKE_LOCAL_PATH ""
    else
        nds_cfg_set FLAKE_LOCAL_PATH "$loc"
        nds_cfg_set FLAKE_REPO_URL ""
    fi
    return 0
}

# Description: Resolve existing location from AA/store; 1 when missing.
nds_flake_gate_logic_existing_location() {
    local loc
    loc="$(nds_cfg_get FLAKE_REPO_URL)"
    [[ -z "$loc" ]] && loc="$(nds_cfg_get FLAKE_LOCAL_PATH)"
    [[ -z "$loc" ]] && loc="$(nds_cfg_get FLAKE_LOCATION)"
    [[ -n "$loc" ]] || return 1
    nds_flake_gate_logic_normalize_location "$loc"
}

# Description: Unattended install mode / disk / remote IP validation.
nds_flake_gate_logic_target_unattended() {
    local mode
    mode="$(nds_cfg_get INSTALL_MODE)"
    mode="${mode:-local}"
    nds_cfg_set INSTALL_MODE "$mode"
    if [[ "$mode" == "remote" ]]; then
        [[ -n "$(nds_cfg_get REMOTE_TARGET_IP)" ]] \
            || { error "Unattended remote install requires REMOTE_TARGET_IP"; return 1; }
    else
        [[ -n "$(nds_cfg_get DISK_TARGET)" ]] \
            || { error "Unattended local install requires DISK_TARGET"; return 1; }
        [[ -z "$(nds_cfg_get DISK_STRATEGY)" ]] && nds_cfg_set DISK_STRATEGY "nds"
    fi
    return 0
}

# Description: Apply default flake fields when empty.
nds_flake_gate_logic_seed_defaults() {
    [[ -z "$(nds_cfg_get FLAKE_HOST_DIR)" ]] && nds_cfg_set FLAKE_HOST_DIR "hosts/x86_64-linux"
    [[ -z "$(nds_cfg_get FLAKE_INSTALL_PATH)" ]] && nds_cfg_set FLAKE_INSTALL_PATH "/mnt/etc/nixos"
    [[ -z "$(nds_cfg_get FLAKE_HARDWARE_PLACEMENT)" ]] && nds_cfg_set FLAKE_HARDWARE_PLACEMENT "host-dir"
}

# Description: Ensure git access; writes path into nameref.
# Arguments:
# - mode:      <String> interactive|unattended
# - cfg:       <Nameref> Config AA (same AA bound for nested git UI)
# - nameref_out: <Nameref> Receives flake root for host listing
nds_flake_gate_logic_ensure_access() {
    local mode="$1"
    local -n _fg_cfg=$2
    local -n _root_out=$3
    local repo_url local_path probe

    repo_url="${_fg_cfg[FLAKE_REPO_URL]:-}"
    local_path="${_fg_cfg[FLAKE_LOCAL_PATH]:-}"

    if [[ -n "$local_path" && -d "$local_path" ]]; then
        nds_git_ensure_flake_closure_access "$local_path" "$repo_url" || return 1
        _root_out="$local_path"
        return 0
    fi

    if [[ -n "$repo_url" ]]; then
        nds_git_access_run "$mode" _fg_cfg || return 1
        nds_install_ui_section_flake_access
        nds_git_ensure_flake_closure_access "" "$repo_url" || return 1
        probe="${NDS_FLAKE_PROBE_REPO:-}"
        if [[ -n "$probe" && -d "$probe" ]]; then
            _root_out="$probe"
        else
            probe=$(nds_preflight_probe_flake "$repo_url") || return 1
            _root_out="$probe"
        fi
        return 0
    fi

    error "Flake location required"
    return 1
}
