#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install context (single config read per pipeline)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-08-04
# Description:   Normalize CONFIG_DATA into NDS_CTX_* for install modules
# ==================================================================================================

# Description: Read CONFIG_DATA into NDS_CTX_* globals.
_nds_install_gather_context() {
    NDS_CTX_DISK=$(nds_cfg_get "DISK_TARGET")
    NDS_CTX_DISK_STRATEGY=$(nds_cfg_get "DISK_STRATEGY")
    NDS_CTX_DISK_STRATEGY="${NDS_CTX_DISK_STRATEGY:-nds}"
    NDS_CTX_ENCRYPTION=$(nds_cfg_get "ENCRYPTION")
    NDS_CTX_HOSTNAME=$(nds_cfg_get "NETWORK_HOSTNAME")
    NDS_CTX_REMOTE_UNLOCK=$(nds_cfg_get "ENCRYPTION_REMOTE_UNLOCK")
    NDS_CTX_ENCRYPTION_PASSWORD=$(nds_cfg_get "ENCRYPTION_PASSWORD")
    NDS_CTX_ENCRYPTION_KEY=$(nds_cfg_get "ENCRYPTION_KEY")
    NDS_CTX_ENCRYPTION_PASSWORD_AUTO=$(nds_cfg_get "ENCRYPTION_PASSWORD_AUTO")
    NDS_CTX_ENCRYPTION_PASSWORD_LENGTH=$(nds_cfg_get "ENCRYPTION_PASSWORD_LENGTH")
    NDS_CTX_ENCRYPTION_KEY_AUTO=$(nds_cfg_get "ENCRYPTION_KEY_AUTO")
    NDS_CTX_ENCRYPTION_KEY_LENGTH=$(nds_cfg_get "ENCRYPTION_KEY_LENGTH")
    NDS_CTX_KEY_BOOT_DEVICE=$(nds_cfg_get "ENCRYPTION_KEY_BOOT_DEVICE")
    NDS_CTX_KEY_BOOT_FILE=$(nds_cfg_get "ENCRYPTION_KEY_BOOT_FILE")
    NDS_CTX_REMOTE_NETWORK=$(nds_cfg_get "ENCRYPTION_REMOTE_NETWORK")
    NDS_CTX_NETWORK_IP=$(nds_cfg_get "NETWORK_IP")
    NDS_CTX_REMOTE_PORT=$(nds_cfg_get "ENCRYPTION_REMOTE_PORT")
    [[ -n "$NDS_CTX_REMOTE_PORT" ]] || NDS_CTX_REMOTE_PORT=2222
    NDS_CTX_ADMIN_USER=$(nds_cfg_get "ACCESS_ADMIN_USER")
    NDS_CTX_ADMIN_USER="${NDS_CTX_ADMIN_USER:-admin}"
    NDS_CTX_SSH_PORT=$(nds_cfg_get "ACCESS_SSH_PORT")
    NDS_CTX_SSH_PORT="${NDS_CTX_SSH_PORT:-22}"
    NDS_CTX_SSH_PW_AUTH=$(nds_cfg_get "ACCESS_SSH_PASSWORD_AUTH")
    NDS_CTX_ADMIN_SSH_KEY=$(nds_cfg_get "ACCESS_ADMIN_SSH_KEY")
    NDS_CTX_BOOT_LOADER=$(nds_cfg_get "BOOT_LOADER")
    NDS_CTX_BOOT_UEFI_MODE=$(nds_cfg_get "BOOT_UEFI_MODE")
    NDS_CTX_DISK_FS_TYPE=$(nds_cfg_get "DISK_FS_TYPE")
    NDS_CTX_DISK_FS_TYPE="${NDS_CTX_DISK_FS_TYPE:-ext4}"
    NDS_CTX_DISK_SWAP_SIZE_MIB=$(nds_cfg_get "DISK_SWAP_SIZE_MIB")
    NDS_CTX_DISK_SWAP_SIZE_MIB="${NDS_CTX_DISK_SWAP_SIZE_MIB:-0}"
    NDS_CTX_SEPARATE_HOME=$(nds_cfg_get "SEPARATE_HOME")
    NDS_CTX_SEPARATE_HOME="${NDS_CTX_SEPARATE_HOME:-false}"
    NDS_CTX_HOME_SIZE=$(nds_cfg_get "HOME_SIZE")
    NDS_CTX_HOME_SIZE="${NDS_CTX_HOME_SIZE:-20G}"
    NDS_CTX_DISK_DISKO_CONFIG=$(nds_cfg_get "DISK_DISKO_CONFIG")
    NDS_CTX_ADMIN_PASSWORD_AUTO=$(nds_cfg_get "ACCESS_ADMIN_PASSWORD_AUTO")
    NDS_CTX_ADMIN_PASSWORD_LENGTH=$(nds_cfg_get "ACCESS_ADMIN_PASSWORD_LENGTH")
    NDS_CTX_ADMIN_PASSWORD=$(nds_cfg_get "ACCESS_ADMIN_PASSWORD")
    if [[ -z "$NDS_CTX_ADMIN_PASSWORD" ]] && declare -f nds_sm_secret_read &>/dev/null; then
        NDS_CTX_ADMIN_PASSWORD="$(nds_sm_secret_read ACCESS_ADMIN_PASSWORD)"
    fi
    return 0
}

# Description: Extend base context with flake install fields.
_nds_install_gather_flake_context() {
    _nds_install_gather_context
    NDS_CTX_FLAKE_SOURCE="${NDS_FLAKE_SOURCE:-$(nds_cfg_get "FLAKE_SOURCE")}"
    NDS_CTX_FLAKE_REPO_URL="${NDS_FLAKE_REPO_URL:-$(nds_cfg_get "FLAKE_REPO_URL")}"
    NDS_CTX_FLAKE_LOCAL_PATH="${NDS_FLAKE_LOCAL_PATH:-$(nds_cfg_get "FLAKE_LOCAL_PATH")}"
    NDS_CTX_FLAKE_INSTALL_PATH="${NDS_FLAKE_INSTALL_PATH:-$(nds_cfg_get "FLAKE_INSTALL_PATH")}"
    NDS_CTX_FLAKE_HOST_DIR="${NDS_FLAKE_HOST_DIR:-$(nds_cfg_get "FLAKE_HOST_DIR")}"
    NDS_CTX_HW_PLACEMENT="${NDS_HARDWARE_PLACEMENT:-$(nds_cfg_get "FLAKE_HARDWARE_PLACEMENT")}"
    NDS_CTX_HW_PLACEMENT="${NDS_CTX_HW_PLACEMENT:-host-dir}"
    NDS_CTX_INSTALL_MODE="${NDS_INSTALL_MODE:-$(nds_cfg_get "INSTALL_MODE")}"
    NDS_CTX_INSTALL_MODE="${NDS_CTX_INSTALL_MODE:-local}"
    NDS_CTX_REMOTE_TARGET_IP="${NDS_REMOTE_TARGET_IP:-$(nds_cfg_get "REMOTE_TARGET_IP")}"
    if [[ -z "${NDS_CTX_DISK_STRATEGY:-}" || "$NDS_CTX_DISK_STRATEGY" == "nds" ]]; then
        NDS_CTX_DISK_STRATEGY="${NDS_DISK_STRATEGY:-$NDS_CTX_DISK_STRATEGY}"
        NDS_CTX_DISK_STRATEGY="${NDS_CTX_DISK_STRATEGY:-nds}"
    fi
    return 0
}

# Description: Ensure base install context is populated.
nds_install_ctx_ensure() {
    [[ -n "${NDS_CTX_DISK+x}" ]] || _nds_install_gather_context
}

# Description: Read one NDS_CTX_* field by short name (DISK → NDS_CTX_DISK).
# Arguments:
# - name: <String> Short context key (DISK, BOOT_LOADER, FLAKE_REPO_URL, …)
# Returns:
# - <String> value on stdout
nds_install_ctx_get() {
    local name="$1"
    local var="NDS_CTX_${name}"
    printf '%s\n' "${!var:-}"
}
