#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake install pipeline (local + remote nixos-anywhere)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-08-19
# ==================================================================================================

# Description: Full flake-based NixOS install.
nds_nixos_install_flake() {
    local flake_root host_dir hostname host_dir_rel

    _nds_install_gather_flake_context
    hostname="$NDS_CTX_HOSTNAME"

    if [[ -z "$hostname" ]]; then
        error "NETWORK_HOSTNAME must be set before flake install"
    fi

    if [[ "$NDS_CTX_INSTALL_MODE" == "remote" ]]; then
        if [[ -z "$NDS_CTX_REMOTE_TARGET_IP" ]]; then
            error "REMOTE_TARGET_IP is required when INSTALL_MODE=remote"
        fi

        nds_install_log "installFlake: remote host=${hostname} target=${NDS_CTX_REMOTE_TARGET_IP}"
        NDS_UI_QUIET=true

        if ! flake_root=$(_nds_install_resolve_flake_root "$NDS_CTX_FLAKE_SOURCE" "$NDS_CTX_FLAKE_LOCAL_PATH" "$NDS_CTX_FLAKE_REPO_URL"); then
            return 1
        fi
        export NDS_FLAKE_ROOT="$flake_root"

        if [[ "$NDS_CTX_ENCRYPTION" == "true" ]]; then
            nds_step_exec "Generating encryption secrets" _nds_install_generate_encryption_secrets || return 1
        fi

        if declare -f nds_git_prefetch_flake_closure &>/dev/null; then
            nds_step_exec "Prefetching flake git inputs" \
                nds_git_prefetch_flake_closure "$flake_root" || return 1
        fi

        nds_step_exec_nixos "Installing via nixos-anywhere" \
            _nds_install_via_nixos_anywhere "$flake_root" "$hostname" "$NDS_CTX_REMOTE_TARGET_IP" || return 1

        nds_install_log "installFlake: remote completed ${flake_root}#${hostname}"
        return 0
    fi

    nds_install_log "installFlake: host=${hostname} strategy=${NDS_CTX_DISK_STRATEGY} hw=${NDS_CTX_HW_PLACEMENT}"

    NDS_UI_QUIET=true

    if [[ "$NDS_CTX_DISK_STRATEGY" == "flake" ]]; then
        nds_step_exec "Verifying /mnt (flake-owned disk)" bash -c '
            mountpoint -q /mnt
        ' || {
            error "/mnt is not mounted — required when disk strategy is flake"
            return 1
        }
    else
        if ! nds_install_auto true; then
            return 1
        fi
    fi

    case "$NDS_CTX_FLAKE_SOURCE" in
        local)
            nds_step_exec "Staging flake on target disk" \
                _nds_install_stage_local_flake "$NDS_CTX_FLAKE_LOCAL_PATH" "$NDS_CTX_FLAKE_INSTALL_PATH" || return 1
            ;;
        remote|*)
            if [[ -z "$NDS_CTX_FLAKE_REPO_URL" ]]; then
                error "FLAKE_REPO_URL is required for remote flake source"
            fi
            nds_step_exec "Staging flake on target disk" \
                _nds_install_ensure_flake_checkout "$NDS_CTX_FLAKE_REPO_URL" "$NDS_CTX_FLAKE_INSTALL_PATH" || return 1
            ;;
    esac
    flake_root="$NDS_CTX_FLAKE_INSTALL_PATH"
    export NDS_FLAKE_ROOT="$flake_root"

    host_dir_rel="$NDS_CTX_FLAKE_HOST_DIR"
    [[ -z "$host_dir_rel" ]] && host_dir_rel="hosts/x86_64-linux"
    host_dir="${flake_root}/${host_dir_rel}/${hostname}"

    if [[ "$NDS_CTX_HW_PLACEMENT" != "skip" ]]; then
        nds_step_exec "Generating hardware facts for flake host" \
            _nds_install_place_hardware_artifact "$host_dir" "$NDS_CTX_HW_PLACEMENT" true || return 1
    else
        log "Skipping hardware artifact (FLAKE_HARDWARE_PLACEMENT=skip)"
    fi

    nds_step_exec "Writing boot module from preset" \
        nds_nixcfg_write_boot_module "${host_dir}/boot.nix" || return 1
    nds_install_log "boot: wrote ${host_dir}/boot.nix from boot preset"

    nds_step_exec "Writing mounts (root/boot UUID)" \
        _nds_install_write_mounts_nix "$NDS_CTX_DISK" "$hostname" "$flake_root" "$NDS_CTX_ENCRYPTION" "$host_dir_rel" || return 1

    nds_step_exec "Writing hypervisor guest tools" \
        _nds_install_flake_write_guest_nix "$host_dir" || return 1

    nds_step_exec "Patching host configuration imports" \
        _nds_install_ensure_host_imports "$host_dir" || return 1

    nds_step_exec "Staging committed host structure in git" \
        _nds_install_flake_git_stage_committed_files "$flake_root" "$host_dir" || return 1

    if declare -f nds_git_prefetch_flake_closure &>/dev/null; then
        nds_step_exec "Prefetching flake git inputs" \
            nds_git_prefetch_flake_closure "$flake_root" || return 1
    fi

    nds_step_exec_nixos "Installing NixOS from flake" \
        _nds_install_nixos_flake "$flake_root" "$hostname" "$NDS_CTX_HW_PLACEMENT" || return 1

    nds_step_exec "Installing git SSH keys on target" \
        nds_git_install_keys_to_target "/mnt" "$flake_root" || return 1

    nds_step_exec "Enrolling sops age key" \
        _nds_sops_enroll_key "$flake_root" "$hostname" "/mnt" || return 1

    nds_step_exec "Registering EFI boot entry" \
        _nds_install_register_efi_entry "$NDS_CTX_DISK" || return 1

    nds_step_exec "Verifying installation" \
        nds_install_verify_local || return 1

    nds_install_log "installFlake: completed ${flake_root}#${hostname}"
    return 0
}
