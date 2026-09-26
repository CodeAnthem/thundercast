#!/usr/bin/env bash
# ==================================================================================================
# NDS - nixcfg classic install orchestration
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-09-26
# Description:   Reads a recipe array and calls the nixcfg blocks.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nixcfg_base_auto() {
    nixcfg_register "nix" 'nix.settings.experimental-features = [ "nix-command" "flakes" ];' 70
}

nixcfg_access_auto() {
    local -n _R=$1
    local admin_user sudo_password ssh_enable ssh_port ssh_pw_auth admin_ssh_key admin_password pw_file
    admin_user=${_R[ACCESS_ADMIN_USER]:-}
    sudo_password=${_R[ACCESS_SUDO_PASSWORD_REQUIRED]:-}
    ssh_enable=${_R[ACCESS_SSH_ENABLE]:-}
    ssh_port=${_R[ACCESS_SSH_PORT]:-}
    ssh_pw_auth=${_R[ACCESS_SSH_PASSWORD_AUTH]:-}
    admin_ssh_key=${_R[ACCESS_ADMIN_SSH_KEY]:-}
    pw_file=${_R[ACCESS_ADMIN_PASSWORD_FILE]:-}
    [[ -f "$pw_file" ]] || {
        error "ACCESS_ADMIN_PASSWORD_FILE: missing"
        return 1
    }
    admin_password=$(<"$pw_file")
    _nixcfg_access_generate "$admin_user" "$sudo_password" "$ssh_enable" "$ssh_port" "$ssh_pw_auth" "$admin_ssh_key" "$admin_password"
}

nixcfg_boot_auto() {
    local -n _R=$1
    _nixcfg_boot_generate "${_R[BOOT_LOADER]:-}" "${_R[BOOT_UEFI_MODE]:-}" "${_R[DISK_TARGET]:-}"
}

nixcfg_boot_auto_flake() {
    local -n _R=$1
    _nixcfg_boot_generate_flake "${_R[BOOT_LOADER]:-}" "${_R[BOOT_UEFI_MODE]:-}" "${_R[DISK_TARGET]:-}"
}

nixcfg_luks_auto() {
    local -n _R=$1
    [[ ${_R[ENCRYPTION]:-} == true ]] || return 0
    [[ ${_R[ENCRYPTION_KEY]:-} == true ]] || return 0
    _nixcfg_luks_generate "${_R[ENCRYPTION_PASSWORD]:-}" "${_R[ENCRYPTION_KEY]:-}" \
        "${_R[ENCRYPTION_KEY_BOOT_DEVICE]:-}" "${_R[ENCRYPTION_KEY_BOOT_FILE]:-}" \
        "${_R[ENCRYPTION_KEY_LENGTH]:-}"
}

nixcfg_network_auto() {
    local -n _R=$1
    local prefix
    if [[ ${_R[NETWORK_METHOD]:-} == static ]]; then
        prefix=${ _nixcfg_netmask_to_prefix "${_R[NETWORK_MASK]:-}"; }
        _nixcfg_network_static "${_R[NETWORK_HOSTNAME]:-}" "${_R[NETWORK_IP]:-}" \
            "${_R[NETWORK_GATEWAY]:-}" "$prefix" "${_R[NETWORK_DNS_PRIMARY]:-}" \
            "${_R[NETWORK_DNS_SECONDARY]:-}"
    else
        _nixcfg_network_dhcp "${_R[NETWORK_HOSTNAME]:-}" "${_R[NETWORK_DNS_PRIMARY]:-}" \
            "${_R[NETWORK_DNS_SECONDARY]:-}" "${_R[ENCRYPTION_REMOTE_UNLOCK]:-}"
    fi
}

nixcfg_remoteUnlock_auto() {
    local -n _R=$1
    local remote_port show_hint shutdown_sec prefix ip_only
    [[ ${_R[ENCRYPTION]:-} == true && ${_R[ENCRYPTION_REMOTE_UNLOCK]:-} == true ]] || return 0
    remote_port=${_R[ENCRYPTION_REMOTE_PORT]:-2222}
    show_hint=${_R[ENCRYPTION_REMOTE_HINT]:-true}
    [[ "$show_hint" == false ]] || show_hint=true
    shutdown_sec=${ _nixcfg_remoteUnlock_shutdown_sec "${_R[ENCRYPTION_REMOTE_SHUTDOWN]:-}"; }
    if [[ ${_R[ENCRYPTION_REMOTE_NETWORK]:-} == static ]]; then
        prefix=${ _nixcfg_netmask_to_prefix "${_R[NETWORK_MASK]:-24}"; }
        ip_only=${_R[NETWORK_IP]%/*}
        _nixcfg_remoteUnlock_generate "$remote_port" "${_R[ENCRYPTION_REMOTE_SSH_KEY]:-}" \
            static "$ip_only" "$prefix" "${_R[NETWORK_GATEWAY]:-}" "$show_hint" "$shutdown_sec"
    else
        _nixcfg_remoteUnlock_generate "$remote_port" "${_R[ENCRYPTION_REMOTE_SSH_KEY]:-}" \
            dhcp "" "" "" "$show_hint" "$shutdown_sec"
    fi
}

nixcfg_region_auto() {
    local -n _R=$1
    _nixcfg_region_generate "${_R[REGION_TIMEZONE]:-}" "${_R[REGION_LOCALE_MAIN]:-}" \
        "${_R[REGION_LOCALE_EXTRA]:-}" "${_R[REGION_KEYBOARD_LAYOUT]:-}" \
        "${_R[REGION_KEYBOARD_VARIANT]:-}"
}

nixcfg_virtualisation_auto() {
    local -n _R=$1
    [[ ${_R[PLATFORM_RUN_ON_VM]:-} == true && ${_R[PLATFORM_VM_GUEST_TOOLS]:-} == true ]] || return 0
    _nixcfg_virtualisation_generate "${_R[PLATFORM_VM_TYPE]:-}"
}

nixcfg_build_classic_auto() {
    local _nixcfg_name=$1
    nixcfg_clear
    nixcfg_boot_auto "$_nixcfg_name"
    nixcfg_luks_auto "$_nixcfg_name"
    nixcfg_remoteUnlock_auto "$_nixcfg_name"
    nixcfg_network_auto "$_nixcfg_name"
    nixcfg_region_auto "$_nixcfg_name"
    nixcfg_access_auto "$_nixcfg_name" || return 1
    _nixcfg_packages_generate
    nixcfg_virtualisation_auto "$_nixcfg_name"
    nixcfg_base_auto
}

nixcfg_writeClassic() {
    local _nixcfg_name=$1 _nixcfg_out=$2
    nixcfg_build_classic_auto "$_nixcfg_name" || return 1
    nixcfg_write "$_nixcfg_out"
}

nixcfg_write_boot_module() {
    local _nixcfg_name=$1 _nixcfg_out=$2
    nixcfg_clear
    nixcfg_boot_auto_flake "$_nixcfg_name"
    nixcfg_write_module "$_nixcfg_out"
    nixcfg_clear
}
