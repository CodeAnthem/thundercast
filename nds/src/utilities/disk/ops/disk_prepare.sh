#!/usr/bin/env bash
# ==================================================================================================
# disk utility - high-level prepare (no UI, no hardware gen)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# ==================================================================================================

# Description: LUKS format callback used by disk_prepare (closes over prepare opts).
_disk_prepare_format_luks() {
    local partition="$1"
    disk_luksFormat "$partition" "${_DISK_PREPARE_USE_PASSWORD}" "${_DISK_PREPARE_USE_KEY}" "${_DISK_PREPARE_SECRETS_DIR}"
}

# Description: Prepare target disk from options nameref.
# Keys: strategy(nds|disko|flake), disk, encryption, uefi_mode, secrets_dir,
#   use_password, use_key, fs_type, swap_mib, separate_home, home_size,
#   unlock_mode, disko_user, boot_loader, work_dir, mount_root, remote_unlock,
#   password_auto, password_length, key_auto, key_length, passphrase_file, keyfile_src
# Does not: step UI, hardware/facter, nix store GC.
disk_prepare() {
    local -n _dp=$1
    local strategy="${_dp[strategy]:-nds}"
    local disk="${_dp[disk]:-}"
    local encryption="${_dp[encryption]:-false}"
    local uefi_mode="${_dp[uefi_mode]:-}"
    local secrets_dir="${_dp[secrets_dir]:-}"
    local mount_root="${_dp[mount_root]:-/mnt}"
    local remote_unlock="${_dp[remote_unlock]:-false}"
    local use_password="${_dp[use_password]:-false}"
    local use_key="${_dp[use_key]:-false}"

    if [[ "$strategy" == "flake" ]]; then
        warn "disk strategy 'flake' skips partitioning — mount root must already be ready"
        return 0
    fi

    [[ -n "$disk" ]] || { err "disk required"; return 1; }
    disk_unmountTarget "$mount_root" || return 1

    if [[ "$strategy" == "disko" ]]; then
        local unlock="${_dp[unlock_mode]:-manual}"
        if [[ "$encryption" == "true" && "$use_key" == "true" && "$use_password" != "true" ]]; then
            unlock="keyfile"
        fi
        disk_diskoApply \
            "$disk" \
            "${_dp[fs_type]:-btrfs}" \
            "${_dp[swap_mib]:-0}" \
            "${_dp[separate_home]:-false}" \
            "${_dp[home_size]:-20G}" \
            "$encryption" \
            "$unlock" \
            "${_dp[disko_user]:-}" \
            "${_dp[boot_loader]:-systemd-boot}" \
            "${_dp[work_dir]:-}" || return 1
    else
        if [[ "$encryption" == "true" ]]; then
            [[ -n "$secrets_dir" ]] || { err "secrets_dir required for encryption"; return 1; }
            declare -A _sec=(
                [secrets_dir]="$secrets_dir"
                [use_password]="$use_password"
                [use_key]="$use_key"
                [password_auto]="${_dp[password_auto]:-true}"
                [password_length]="${_dp[password_length]:-32}"
                [key_auto]="${_dp[key_auto]:-true}"
                [key_length]="${_dp[key_length]:-64}"
                [passphrase_file]="${_dp[passphrase_file]:-}"
                [keyfile_src]="${_dp[keyfile_src]:-}"
            )
            disk_writeEncryptionSecrets _sec || return 1
            [[ -n "${_sec[passphrase_file]:-}" ]] && _dp[passphrase_file]="${_sec[passphrase_file]}"
            _DISK_PREPARE_USE_PASSWORD="$use_password"
            _DISK_PREPARE_USE_KEY="$use_key"
            _DISK_PREPARE_SECRETS_DIR="$secrets_dir"
            export _DISK_PREPARE_USE_PASSWORD _DISK_PREPARE_USE_KEY _DISK_PREPARE_SECRETS_DIR
            disk_partition "$disk" true "$uefi_mode" _disk_prepare_format_luks || return 1
            unset _DISK_PREPARE_USE_PASSWORD _DISK_PREPARE_USE_KEY _DISK_PREPARE_SECRETS_DIR
        else
            disk_partition "$disk" false "$uefi_mode" || return 1
        fi
        disk_mountRoot "$encryption" "$mount_root" || return 1
    fi

    if [[ "$encryption" == "true" && "$remote_unlock" == "true" ]]; then
        disk_setupInitrdSshKeys "$mount_root" "$secrets_dir" || return 1
    fi
    return 0
}
