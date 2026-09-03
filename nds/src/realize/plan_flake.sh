#!/usr/bin/env bash
# ==================================================================================================
# NDS realize - flake plans (local nixos-install --flake, remote nixos-anywhere)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-09-03
# ==================================================================================================

# Description: Flake host name (FLAKE_HOST, mirrored from NETWORK_HOSTNAME by compose).
_nds_realize_flake_host() {
    local host
    host="$(nds_cfg_get FLAKE_HOST)"
    [[ -n "$host" ]] || host="$(nds_cfg_get NETWORK_HOSTNAME)"
    printf '%s\n' "$host"
}

# Description: Flake source: remote when a repo URL is set, local when a path is set.
_nds_realize_flake_source() {
    local source
    if [[ -n "$(nds_cfg_get FLAKE_REPO_URL)" ]]; then source="remote"
    elif [[ -n "$(nds_cfg_get FLAKE_LOCAL_PATH)" ]]; then source="local"
    else source="$(nds_cfg_get FLAKE_SOURCE)"; fi
    printf '%s\n' "${source:-remote}"
}

# Description: Local flake recipe (disk → stage flake → host files → build → activate → verify).
# Returns:
# - <Int> 0 on success; 15 on failure
_nds_realize_plan_flake_local() {
    local host source repo_url local_path install_path host_dir_rel host_dir hw_placement
    local disk strategy encryption remote_unlock loader uefi

    host="${ _nds_realize_flake_host; }"
    [[ -n "$host" ]] || { error "FLAKE_HOST / NETWORK_HOSTNAME must be set before flake install"; return 15; }
    source="${ _nds_realize_flake_source; }"
    repo_url="$(nds_cfg_get FLAKE_REPO_URL)"
    local_path="$(nds_cfg_get FLAKE_LOCAL_PATH)"
    install_path="$(nds_cfg_get FLAKE_INSTALL_PATH)"
    host_dir_rel="$(nds_cfg_get FLAKE_HOST_DIR)"; host_dir_rel="${host_dir_rel:-hosts/x86_64-linux}"
    hw_placement="$(nds_cfg_get FLAKE_HARDWARE_PLACEMENT)"; hw_placement="${hw_placement:-host-dir}"
    disk="$(nds_cfg_get DISK_TARGET)"
    strategy="$(nds_cfg_get DISK_STRATEGY)"; strategy="${strategy:-nds}"
    encryption="$(nds_cfg_get ENCRYPTION)"
    remote_unlock="$(nds_cfg_get ENCRYPTION_REMOTE_UNLOCK)"
    loader="$(nds_cfg_get BOOT_LOADER)"; loader="${loader:-grub}"
    uefi="$(nds_cfg_get BOOT_UEFI_MODE)"
    [[ -n "$install_path" ]] || { error "FLAKE_INSTALL_PATH is required"; return 15; }
    host_dir="${install_path}/${host_dir_rel}/${host}"

    nds_requireUtility nixos || return 15
    nds_requireUtility flake || return 15
    nds_requireUtility nixcfg || return 15
    nixos_setBootContext "$loader" "$uefi" "$disk" "$encryption"
    nds_install_log "realize: flake host=${host} strategy=${strategy} hw=${hw_placement}"
    NDS_UI_QUIET=true

    if [[ "$strategy" == "flake" ]]; then
        nds_step_exec "Verifying /mnt (flake-owned disk)" mountpoint -q /mnt || {
            error "/mnt is not mounted — required when disk strategy is flake"
            return 15
        }
    else
        _nds_realize_disk_prepare "$disk" "$strategy" "$encryption" "$remote_unlock" "$uefi" "$loader" || return 15
    fi

    nds_step_exec "Staging flake on target disk" \
        _nds_realize_stage_flake "$source" "$local_path" "$repo_url" "$install_path" || return 15

    if [[ "$hw_placement" != "skip" ]]; then
        nds_step_exec "Generating hardware facts for flake host" \
            _nds_realize_place_hardware "$host_dir" "$hw_placement" || return 15
    else
        log "Skipping hardware artifact (FLAKE_HARDWARE_PLACEMENT=skip)"
    fi

    nds_step_exec "Writing NDS generated host module" \
        nds_nixcfg_write_generated_host "$host_dir" "$host" "$disk" "$encryption" "$install_path" || return 15
    nds_step_exec "Verifying host structural files" flake_hostStructureOk "$host_dir" || return 15
    nds_step_exec "Staging host files for flake eval" \
        _nds_realize_flake_git_stage "$install_path" "$host_dir" || return 15

    nds_step_exec "Prefetching flake git inputs" nds_git_prefetch_flake_closure "$install_path" || return 15
    nds_step_exec "Checking flake" nixos_flakeEval "$install_path" "$host" || return 15
    nds_step_exec_nixos "Installing NixOS from flake" \
        _nds_realize_nixos_flake "$install_path" "$host" "$host_dir" "$hw_placement" || return 15
    nds_realize_diag_snapshot "after install"

    nds_step_exec "Installing git SSH keys on target" nds_install_git_keys_to_target /mnt "$install_path" || return 15
    nds_step_exec "Enrolling sops age key" _nds_sops_enroll_key "$install_path" "$host" /mnt || return 15
    nds_step_exec "Registering EFI boot entry" _nds_realize_register_efi "$disk" "$uefi" "$loader" || return 15
    nds_step_exec "Verifying installation" nds_realize_verify flake "$install_path" || return 15
    return 0
}

# Description: Remote flake recipe (operator machine → nixos-anywhere on target).
# Returns:
# - <Int> 0 on success; 15 on failure
_nds_realize_plan_flake_remote() {
    local host source repo_url local_path host_dir_rel target_ip encryption flake_root luks_key=""

    host="${ _nds_realize_flake_host; }"
    [[ -n "$host" ]] || { error "FLAKE_HOST / NETWORK_HOSTNAME must be set before flake install"; return 15; }
    source="${ _nds_realize_flake_source; }"
    repo_url="$(nds_cfg_get FLAKE_REPO_URL)"
    local_path="$(nds_cfg_get FLAKE_LOCAL_PATH)"
    host_dir_rel="$(nds_cfg_get FLAKE_HOST_DIR)"; host_dir_rel="${host_dir_rel:-hosts/x86_64-linux}"
    target_ip="$(nds_cfg_get REMOTE_TARGET_IP)"
    encryption="$(nds_cfg_get ENCRYPTION)"
    [[ -n "$target_ip" ]] || { error "REMOTE_TARGET_IP is required when INSTALL_MODE=remote"; return 15; }

    nds_requireUtility nixos || return 15
    nds_install_log "realize: remote host=${host} target=${target_ip}"
    NDS_UI_QUIET=true

    if [[ "$source" == "local" ]]; then
        [[ -n "$local_path" && -d "$local_path" ]] || { error "Local flake path not found: ${local_path}"; return 15; }
        flake_root="$local_path"
    else
        flake_root="${NDS_RUNTIME_DIR}/flake_install"
        nds_step_exec "Staging flake" _nds_realize_stage_flake remote "" "$repo_url" "$flake_root" || return 15
    fi

    if [[ "$encryption" == "true" ]]; then
        nds_step_exec "Generating encryption secrets" _nds_realize_encryption_secrets "${NDS_RUNTIME_DIR}/secrets" || return 15
        luks_key="${NDS_RUNTIME_DIR}/secrets/luks_key.bin"
    fi

    nds_step_exec "Prefetching flake git inputs" nds_git_prefetch_flake_closure "$flake_root" || return 15
    nds_step_exec "Checking flake" nixos_flakeEval "$flake_root" "$host" || return 15
    nds_step_exec_nixos "Installing via nixos-anywhere" \
        nixos_anywhere "$flake_root" "$host" "$target_ip" \
            "${flake_root}/${host_dir_rel}/${host}/facter.json" "$luks_key" || return 15
    return 0
}

# Description: Build on the target store, drop facts from the git index, activate, repair.
# Arguments:
# - flake_root:   <String> Flake checkout on the target disk
# - host:         <String> nixosConfigurations key
# - host_dir:     <String> Host directory
# - hw_placement: <String> host-dir | etc-nixos | skip
_nds_realize_nixos_flake() {
    local flake_root="$1" host="$2" host_dir="$3" hw_placement="$4"
    local system_rel
    local -a build_flags=()

    if [[ "$hw_placement" == "etc-nixos" && -f /mnt/etc/nixos/hardware-configuration.nix ]] \
        && [[ "${ _nds_realize_hw_artifact_name; }" == "hardware-configuration.nix" ]]; then
        build_flags+=(--override-input hardware "path:/etc/nixos/hardware-configuration.nix")
        log "Using --override-input hardware path:/etc/nixos/hardware-configuration.nix"
    fi

    log "Building NixOS system on target store"
    system_rel=$(nixos_buildFlakeSystem "$flake_root" "$host" "${build_flags[@]}") || {
        error "Flake-based NixOS build failed"
        return 1
    }
    nds_install_log "nix: built system ${system_rel}"

    # Keep host facts on disk but out of the index so post-boot `git pull --ff-only` works.
    flake_gitUnstageHostFacts "$flake_root" "$host_dir" || true

    log "Activating system (profile + bootloader)"
    nixos_activateSystem /mnt "$system_rel" >>"${NDS_NIXOS_INSTALL_LOG:-/tmp/nds_nixosInstallation.log}" 2>&1 || {
        error "Flake-based NixOS activation failed — see ${NDS_NIXOS_INSTALL_LOG:-/tmp/nds_nixosInstallation.log}"
        return 1
    }
    nixos_ensureInstallArtifacts || return 1
    return 0
}
