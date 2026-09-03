#!/usr/bin/env bash
# ==================================================================================================
# NDS realize - disk steps (secrets → partition/disko → mount → initrd keys)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-09-03
# Description:   Prompts (passphrase/keyfile) live in wizard/install/ui; ops in utilities/disk.
# ==================================================================================================

# Description: Generate or collect LUKS unlock secrets into secrets_dir.
# Arguments:
# - secrets_dir: <String> Runtime secrets directory
_nds_realize_encryption_secrets() {
    local secrets_dir="$1"
    local use_password use_key password_auto use_key_auto given_file passphrase_tmp="" keyfile_src=""
    local -A _sec

    nds_requireUtility disk || return 1
    use_password="$(nds_cfg_get ENCRYPTION_PASSWORD)"
    use_key="$(nds_cfg_get ENCRYPTION_KEY)"
    password_auto="$(nds_cfg_get ENCRYPTION_PASSWORD_AUTO)"
    use_key_auto="$(nds_cfg_get ENCRYPTION_KEY_AUTO)"
    mkdir -p "$secrets_dir" || { error "Cannot create secrets dir"; return 1; }

    given_file="$(nds_cfg_get ENCRYPTION_PASSPHRASE_FILE)"
    if [[ "$use_password" == "true" && "$password_auto" != "true" ]]; then
        if [[ -z "$given_file" || ! -f "$given_file" ]]; then
            passphrase_tmp="${secrets_dir}/.prompt_passphrase"
            printf '%s' "$(nds_encryption_prompts_password)" >"$passphrase_tmp"
            chmod 600 "$passphrase_tmp"
            given_file="$passphrase_tmp"
        fi
    fi
    if [[ "$use_key" == "true" && "$use_key_auto" != "true" ]]; then
        keyfile_src="$(nds_encryption_prompts_keyfile_path)"
    fi

    _sec=(
        [secrets_dir]="$secrets_dir"
        [use_password]="$use_password"
        [use_key]="$use_key"
        [password_auto]="$password_auto"
        [password_length]="$(nds_cfg_get ENCRYPTION_PASSWORD_LENGTH)"
        [key_auto]="$use_key_auto"
        [key_length]="$(nds_cfg_get ENCRYPTION_KEY_LENGTH)"
        [passphrase_file]="${given_file:-}"
        [keyfile_src]="$keyfile_src"
    )
    disk_writeEncryptionSecrets _sec || return 1

    [[ "$use_password" == "true" ]] && nds_install_log "Generated LUKS password (secrets/luks_password.txt)"
    [[ "$use_key" == "true" ]] && nds_install_log "Generated LUKS keyfile (secrets/luks_key.bin)"
    [[ -n "$passphrase_tmp" && -f "$passphrase_tmp" ]] && rm -f "$passphrase_tmp"
    return 0
}

# Description: LUKS2 format callback for disk_partition (uses secrets written above).
# Arguments:
# - partition: <String> Root partition device
_nds_realize_luks_format() {
    disk_luksFormat "$1" "$(nds_cfg_get ENCRYPTION_PASSWORD)" "$(nds_cfg_get ENCRYPTION_KEY)" \
        "${NDS_RUNTIME_DIR}/secrets" || return 1
    nds_install_log "LUKS2 formatted on $1; root fs created"
    return 0
}

# Description: Partition with NDS layout (optionally LUKS) and mount under /mnt.
# Arguments:
# - disk:       <String> Target block device
# - encryption: <String> true | false
# - uefi:       <String> true | false | "" (detect)
_nds_realize_partition_and_mount() {
    local disk="$1" encryption="$2" uefi="$3"

    if [[ "$encryption" == "true" ]]; then
        disk_partition "$disk" "$encryption" "$uefi" _nds_realize_luks_format || return 1
    else
        disk_partition "$disk" "$encryption" "$uefi" || return 1
    fi
    nds_realize_diag_after_partition "$disk"
    disk_mountRoot "$encryption" /mnt || return 1
    nds_realize_diag_snapshot "after mount"
    return 0
}

# Description: Disko layout from settings (or user disko config), then diagnostics.
# Arguments:
# - disk:       <String> Target block device
# - encryption: <String> true | false
# - loader:     <String> Bootloader id
_nds_realize_disko() {
    local disk="$1" encryption="$2" loader="$3"
    local unlock="manual" use_pass use_key rc=0

    use_pass="$(nds_cfg_get ENCRYPTION_PASSWORD)"
    use_key="$(nds_cfg_get ENCRYPTION_KEY)"
    if [[ "$encryption" == "true" && "$use_key" == "true" && "$use_pass" != "true" ]]; then
        unlock="keyfile"
    fi
    disk_diskoApply "$disk" \
        "$(nds_cfg_get DISK_FS_TYPE)" "$(nds_cfg_get DISK_SWAP_SIZE_MIB)" \
        "$(nds_cfg_get SEPARATE_HOME)" "$(nds_cfg_get HOME_SIZE)" \
        "$encryption" "$unlock" "$(nds_cfg_get DISK_DISKO_CONFIG)" "$loader" \
        "${NDS_RUNTIME_DIR}/disko" || rc=$?
    nds_realize_diag_after_partition "$disk"
    return "$rc"
}

# Description: Full disk preparation sequence (steps with UI).
# Arguments:
# - disk:          <String> Target block device
# - strategy:      <String> nds | disko
# - encryption:    <String> true | false
# - remote_unlock: <String> true | false (initrd SSH keys)
# - uefi:          <String> BOOT_UEFI_MODE
# - loader:        <String> BOOT_LOADER id
_nds_realize_disk_prepare() {
    local disk="$1" strategy="$2" encryption="$3" remote_unlock="$4" uefi="$5" loader="$6"

    nds_requireUtility disk || return 1
    nds_requireUtility nixos || return 1
    [[ -n "$disk" ]] || { error "DISK_TARGET is required"; return 1; }
    log "Disk: ${disk} | strategy: ${strategy} | encryption: ${encryption}"

    disk_unmountTarget /mnt || return 1
    nixos_ensureLiveStoreSpace 64 || return 1

    if [[ "$encryption" == "true" ]]; then
        nds_step_exec "Generating encryption secrets" _nds_realize_encryption_secrets "${NDS_RUNTIME_DIR}/secrets" || return 1
    fi
    if [[ "$strategy" == "disko" ]]; then
        nds_step_exec "Running disko" _nds_realize_disko "$disk" "$encryption" "$loader" || return 1
    else
        nds_step_exec "Partitioning and mounting" _nds_realize_partition_and_mount "$disk" "$encryption" "$uefi" || return 1
    fi
    if [[ "$encryption" == "true" && "$remote_unlock" == "true" ]]; then
        nds_step_exec "Setting up initrd SSH keys" _nds_realize_initrd_ssh_keys "${NDS_RUNTIME_DIR}/secrets" || return 1
    fi
    log "Disk preparation completed"
    return 0
}

# Description: Initrd SSH host key on /mnt, staged into secrets for the bundle.
# Arguments:
# - secrets_dir: <String> Runtime secrets directory
_nds_realize_initrd_ssh_keys() {
    disk_setupInitrdSshKeys /mnt "$1" || return 1
    nds_install_log "Generated initrd SSH host key (ed25519) for remote unlock"
    return 0
}
