#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-08-28
# Description:   classicConfig builder tests (read-only — writes to temp dir only)
# ==================================================================================================

# Reset all encryption-related config vars to a clean state.
_nds_test_reset_encryption_vars() {
    local v
    for v in ENCRYPTION ENCRYPTION_PASSWORD ENCRYPTION_PASSWORD_AUTO \
             ENCRYPTION_PASSWORD_LENGTH ENCRYPTION_KEY ENCRYPTION_KEY_AUTO \
             ENCRYPTION_KEY_LENGTH ENCRYPTION_KEY_BOOT_DEVICE \
             ENCRYPTION_KEY_BOOT_FILE ENCRYPTION_REMOTE_UNLOCK ENCRYPTION_REMOTE_SSH_KEY \
             ENCRYPTION_REMOTE_NETWORK ENCRYPTION_REMOTE_HINT ENCRYPTION_REMOTE_SHUTDOWN; do
        unset "CONFIG_DATA[$v]"
    done
}

# Seed runtime secrets dir so access_auto never falls through missing password.
_nds_test_seed_admin_password() {
    local dir="$1"
    mkdir -p "${dir}/secrets"
    printf '%s' 'testpass0123456789' > "${dir}/secrets/admin_password.txt"
    export NDS_RUNTIME_DIR="$dir"
}

suite_classic_config() {
    local tmp_dir output content
    local _sv_save="${NDS_NIXOS_STATE_VERSION:-}"

    export NDS_NIXOS_STATE_VERSION="26.05"

    if ! declare -f nds_nixcfg_build_classic_auto &>/dev/null; then
        warn "classicConfig not loaded — skipping builder tests"
        return 0
    fi

    tmp_dir=$(mktemp -d)
    output="${tmp_dir}/configuration.nix"
    _nds_test_seed_admin_password "$tmp_dir"

    CONFIG_DATA[REGION_TIMEZONE]="Europe/Zurich"
    CONFIG_DATA[REGION_LOCALE_MAIN]="en_US.UTF-8"
    CONFIG_DATA[REGION_KEYBOARD_LAYOUT]="ch"
    CONFIG_DATA[REGION_KEYBOARD_VARIANT]="de_nodeadkeys"
    CONFIG_DATA[NETWORK_HOSTNAME]="testhost"
    CONFIG_DATA[NETWORK_METHOD]="dhcp"
    CONFIG_DATA[ACCESS_ADMIN_USER]="admin"
    CONFIG_DATA[ACCESS_SUDO_PASSWORD_REQUIRED]="true"
    CONFIG_DATA[ACCESS_SSH_ENABLE]="true"
    CONFIG_DATA[ACCESS_SSH_PORT]="22"
    CONFIG_DATA[ACCESS_SSH_PASSWORD_AUTH]="true"
    CONFIG_DATA[ACCESS_ADMIN_SSH_KEY]=""
    CONFIG_DATA[BOOT_LOADER]="systemd-boot"
    CONFIG_DATA[BOOT_UEFI_MODE]="true"

    _nds_test_reset_encryption_vars
    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$output"

    content=$(<"$output")
    assert_contains "$content" 'experimental-features' "configuration.nix"
    assert_contains "$content" 'Europe/Zurich' "configuration.nix"
    assert_contains "$content" 'testhost' "configuration.nix"
    assert_contains "$content" 'hardware-configuration.nix' "configuration.nix"
    assert_contains "$content" 'system.stateVersion = "26.05"' "configuration.nix"
    assert_contains "$content" 'Did you read the comment?' "configuration.nix stateVersion blob"
    assert_contains "$content" 'github.com/CodeAnthem/thundercast' "configuration.nix NDS header"
    assert_contains "$content" 'Installed with Nix Deploy System' "configuration.nix NDS header"
    assert_contains "$content" '# Bootloader.' "configuration.nix boot section note"
    assert_contains "$content" 'console.keyMap = "sg"' "configuration.nix Swiss console keymap"
    assert_contains "$content" 'description = "admin"' "configuration.nix user description"
    assert_contains "$content" 'environment.systemPackages' "configuration.nix packages"
    assert_contains "$content" 'networking.wireless.enable' "configuration.nix wireless hint"
    assert_contains "$content" 'networking.firewall.enable' "configuration.nix firewall hint"
    # Plain DHCP (no remote unlock) uses NetworkManager.
    assert_contains "$content" 'networkmanager.enable = true' "configuration.nix"
    assert_contains "$content" 'initialHashedPassword =' "configuration.nix hashes admin password"
    assert_contains "$content" 'systemd-boot.enable = true' "configuration.nix systemd-boot"
    assert_contains "$content" 'efi.efiSysMountPoint =' "configuration.nix ESP mount"
    assert_not_contains "$content" 'testpass0123456789' "configuration.nix must not embed plaintext admin password"

    rm -rf "$tmp_dir"

    # BIOS + mismatched bootloader: must emit GRUB on the target disk, not systemd-boot
    tmp_dir=$(mktemp -d)
    output="${tmp_dir}/configuration.nix"
    _nds_test_seed_admin_password "$tmp_dir"

    CONFIG_DATA[DISK_TARGET]="/dev/sda"
    CONFIG_DATA[BOOT_LOADER]="systemd-boot"
    CONFIG_DATA[BOOT_UEFI_MODE]="false"

    _nds_test_reset_encryption_vars
    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$output"

    content=$(<"$output")
    assert_contains "$content" 'boot.loader.grub' "BIOS configuration.nix"
    assert_contains "$content" 'device = "/dev/sda"' "BIOS configuration.nix"
    assert_not_contains "$content" 'systemd-boot.enable' "BIOS configuration.nix"

    rm -rf "$tmp_dir"

    # Password only: no keyFile block (NixOS prompts at boot)
    tmp_dir=$(mktemp -d)
    output="${tmp_dir}/configuration.nix"
    _nds_test_seed_admin_password "$tmp_dir"

    _nds_test_reset_encryption_vars
    CONFIG_DATA[ENCRYPTION]="true"
    CONFIG_DATA[ENCRYPTION_PASSWORD]="true"
    CONFIG_DATA[ENCRYPTION_KEY]="false"
    CONFIG_DATA[ENCRYPTION_REMOTE_UNLOCK]="false"

    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$output"

    content=$(<"$output")
    assert_not_contains "$content" 'keyFile' "password-only configuration.nix"
    assert_not_contains "$content" 'boot.initrd.secrets' "password-only configuration.nix"

    rm -rf "$tmp_dir"

    # Key only (raw device): keyFile = device, keyFileSize, keyFileTimeout, no fallback
    tmp_dir=$(mktemp -d)
    output="${tmp_dir}/configuration.nix"
    _nds_test_seed_admin_password "$tmp_dir"

    _nds_test_reset_encryption_vars
    CONFIG_DATA[ENCRYPTION]="true"
    CONFIG_DATA[ENCRYPTION_PASSWORD]="false"
    CONFIG_DATA[ENCRYPTION_KEY]="true"
    CONFIG_DATA[ENCRYPTION_KEY_BOOT_DEVICE]="/dev/disk/by-uuid/abcd-1234"
    CONFIG_DATA[ENCRYPTION_KEY_BOOT_FILE]=""
    CONFIG_DATA[ENCRYPTION_KEY_LENGTH]="4096"
    CONFIG_DATA[ENCRYPTION_REMOTE_UNLOCK]="false"

    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$output"

    content=$(<"$output")
    assert_contains "$content" 'keyFile = "/dev/disk/by-uuid/abcd-1234"' "key-raw configuration.nix"
    assert_contains "$content" 'keyFileSize = 4096' "key-raw configuration.nix"
    assert_contains "$content" 'keyFileTimeout = 30' "key-raw configuration.nix"
    assert_not_contains "$content" 'fallbackToPassword' "key-raw configuration.nix"
    assert_not_contains "$content" 'boot.initrd.secrets' "key-raw configuration.nix"
    assert_not_contains "$content" 'systemd.mounts' "key-raw configuration.nix"

    rm -rf "$tmp_dir"

    # Key only (file on filesystem): systemd mount + keyFile on mounted path
    tmp_dir=$(mktemp -d)
    output="${tmp_dir}/configuration.nix"
    _nds_test_seed_admin_password "$tmp_dir"

    _nds_test_reset_encryption_vars
    CONFIG_DATA[ENCRYPTION]="true"
    CONFIG_DATA[ENCRYPTION_PASSWORD]="false"
    CONFIG_DATA[ENCRYPTION_KEY]="true"
    CONFIG_DATA[ENCRYPTION_KEY_BOOT_DEVICE]="/dev/disk/by-uuid/abcd-1234"
    CONFIG_DATA[ENCRYPTION_KEY_BOOT_FILE]="/key.bin"
    CONFIG_DATA[ENCRYPTION_KEY_LENGTH]="4096"
    CONFIG_DATA[ENCRYPTION_REMOTE_UNLOCK]="false"

    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$output"

    content=$(<"$output")
    assert_contains "$content" 'systemd.mounts' "key-file configuration.nix"
    assert_contains "$content" '/mnt-keyusb' "key-file configuration.nix"
    assert_contains "$content" 'keyFile = "/mnt-keyusb/key.bin"' "key-file configuration.nix"
    assert_not_contains "$content" 'keyFileSize' "key-file configuration.nix"
    assert_not_contains "$content" 'fallbackToPassword' "key-file configuration.nix"

    rm -rf "$tmp_dir"

    # Both (raw device + password): keyFile + fallbackToPassword + short timeout
    tmp_dir=$(mktemp -d)
    output="${tmp_dir}/configuration.nix"
    _nds_test_seed_admin_password "$tmp_dir"

    _nds_test_reset_encryption_vars
    CONFIG_DATA[ENCRYPTION]="true"
    CONFIG_DATA[ENCRYPTION_PASSWORD]="true"
    CONFIG_DATA[ENCRYPTION_KEY]="true"
    CONFIG_DATA[ENCRYPTION_KEY_BOOT_DEVICE]="/dev/disk/by-uuid/abcd-1234"
    CONFIG_DATA[ENCRYPTION_KEY_BOOT_FILE]=""
    CONFIG_DATA[ENCRYPTION_KEY_LENGTH]="4096"
    CONFIG_DATA[ENCRYPTION_REMOTE_UNLOCK]="false"

    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$output"

    content=$(<"$output")
    assert_contains "$content" 'keyFile = "/dev/disk/by-uuid/abcd-1234"' "both-raw configuration.nix"
    assert_contains "$content" 'fallbackToPassword = true' "both-raw configuration.nix"
    assert_contains "$content" 'keyFileTimeout = 10' "both-raw configuration.nix"

    rm -rf "$tmp_dir"

    # Remote unlock: initrd SSH + hostKeys + systemd network
    tmp_dir=$(mktemp -d)
    output="${tmp_dir}/configuration.nix"
    _nds_test_seed_admin_password "$tmp_dir"

    _nds_test_reset_encryption_vars
    CONFIG_DATA[ENCRYPTION]="true"
    CONFIG_DATA[ENCRYPTION_PASSWORD]="true"
    CONFIG_DATA[ENCRYPTION_KEY]="false"
    CONFIG_DATA[ENCRYPTION_REMOTE_UNLOCK]="true"
    CONFIG_DATA[ENCRYPTION_REMOTE_SSH_KEY]="ssh-ed25519 AAAAfakeKey test@host"
    CONFIG_DATA[ENCRYPTION_REMOTE_NETWORK]="dhcp"

    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$output"

    content=$(<"$output")
    assert_contains "$content" 'boot.initrd.network.ssh' "remote-unlock configuration.nix"
    assert_contains "$content" 'ssh-ed25519 AAAAfakeKey test@host' "remote-unlock configuration.nix"
    assert_contains "$content" '/etc/secrets/initrd/ssh_host_ed25519_key' "remote-unlock configuration.nix"
    assert_contains "$content" 'boot.initrd.systemd.network' "remote-unlock configuration.nix"
    assert_contains "$content" 'matchConfig.Type = "ether"' "remote-unlock configuration.nix"
    assert_not_contains "$content" 'matchConfig.Name = "eth0"' "remote-unlock configuration.nix"
    assert_contains "$content" 'boot.initrd.availableKernelModules' "remote-unlock configuration.nix"
    assert_contains "$content" 'command="systemctl default 2>/dev/null"' "remote-unlock configuration.nix"
    assert_contains "$content" 'RequiredForOnline = "routable"' "remote-unlock configuration.nix"
    assert_contains "$content" 'boot.initrd.systemd.network.enable = true' "remote-unlock configuration.nix"
    assert_contains "$content" 'dhcpV4Config.ClientIdentifier = "mac"' "remote-unlock configuration.nix"
    # Booted system also uses networkd (MAC id) so its IP matches the initrd.
    assert_contains "$content" 'systemd.network.networks."10-wired"' "remote-unlock configuration.nix"
    assert_not_contains "$content" 'networkmanager.enable = true' "remote-unlock configuration.nix"
    assert_contains "$content" 'nds-show-ip' "remote-unlock configuration.nix"
    assert_contains "$content" 'is-active --quiet sshd' "remote-unlock configuration.nix"
    assert_contains "$content" '"sshd.service"' "remote-unlock configuration.nix"
    assert_contains "$content" 'boot.initrd.systemd.storePaths' "remote-unlock configuration.nix"
    assert_contains "$content" 'TTYPath = "/dev/console"' "remote-unlock configuration.nix"
    assert_contains "$content" 'Remote LUKS unlock:' "remote-unlock configuration.nix"
    assert_contains "$content" 'port = 2222' "remote-unlock configuration.nix"
    assert_contains "$content" 'pkgs.busybox' "remote-unlock configuration.nix"
    assert_contains "$content" 'echo -e' "remote-unlock configuration.nix"
    assert_contains "$content" 'ADDRESS=' "remote-unlock configuration.nix"
    assert_contains "$content" 'systemd-networkd.service' "remote-unlock configuration.nix"
    assert_not_contains "$content" 'wait-online' "remote-unlock configuration.nix"
    assert_not_contains "$content" '-o addr' "remote-unlock configuration.nix"
    assert_not_contains "$content" 'journal+console' "remote-unlock configuration.nix"
    assert_not_contains "$content" 'pkgs.iproute2' "remote-unlock configuration.nix"
    assert_not_contains "$content" 'writeScript' "remote-unlock configuration.nix"
    assert_not_contains "$content" 'writeShellScript' "remote-unlock configuration.nix"
    assert_not_contains "$content" 'StandardOutput = "null"' "remote-unlock configuration.nix"
    assert_not_contains "$content" 'MaxAuthTries' "remote-unlock configuration.nix"
    assert_not_contains "$content" 'nds-unlock-lockout' "remote-unlock configuration.nix"
    assert_not_contains "$content" 'nds-unlock.nft' "remote-unlock configuration.nix"
    assert_not_contains "$content" 'nds-unlock-harden' "remote-unlock configuration.nix"

    rm -rf "$tmp_dir"

    # Remote unlock with console hint disabled: SSH stays, no magenta helper.
    tmp_dir=$(mktemp -d)
    output="${tmp_dir}/configuration.nix"
    _nds_test_seed_admin_password "$tmp_dir"

    _nds_test_reset_encryption_vars
    CONFIG_DATA[ENCRYPTION]="true"
    CONFIG_DATA[ENCRYPTION_PASSWORD]="true"
    CONFIG_DATA[ENCRYPTION_KEY]="false"
    CONFIG_DATA[ENCRYPTION_REMOTE_UNLOCK]="true"
    CONFIG_DATA[ENCRYPTION_REMOTE_SSH_KEY]="ssh-ed25519 AAAAfakeKey test@host"
    CONFIG_DATA[ENCRYPTION_REMOTE_NETWORK]="dhcp"
    CONFIG_DATA[ENCRYPTION_REMOTE_HINT]="false"

    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$output"

    content=$(<"$output")
    assert_contains "$content" 'boot.initrd.network.ssh' "remote-unlock no-hint configuration.nix"
    assert_contains "$content" 'port = 2222' "remote-unlock no-hint configuration.nix"
    assert_not_contains "$content" 'nds-show-ip' "remote-unlock no-hint configuration.nix"
    assert_not_contains "$content" 'Remote LUKS unlock:' "remote-unlock no-hint configuration.nix"
    assert_not_contains "$content" 'pkgs.busybox' "remote-unlock no-hint configuration.nix"

    rm -rf "$tmp_dir"

    # Remote unlock auto power-off: watchdog after N seconds, no LUKS tries override.
    tmp_dir=$(mktemp -d)
    output="${tmp_dir}/configuration.nix"
    _nds_test_seed_admin_password "$tmp_dir"

    _nds_test_reset_encryption_vars
    CONFIG_DATA[ENCRYPTION]="true"
    CONFIG_DATA[ENCRYPTION_PASSWORD]="true"
    CONFIG_DATA[ENCRYPTION_KEY]="false"
    CONFIG_DATA[ENCRYPTION_REMOTE_UNLOCK]="true"
    CONFIG_DATA[ENCRYPTION_REMOTE_SSH_KEY]="ssh-ed25519 AAAAfakeKey test@host"
    CONFIG_DATA[ENCRYPTION_REMOTE_NETWORK]="dhcp"
    CONFIG_DATA[ENCRYPTION_REMOTE_SHUTDOWN]="120"

    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$output"

    content=$(<"$output")
    assert_contains "$content" 'boot.initrd.network.ssh' "remote-unlock shutdown configuration.nix"
    assert_contains "$content" 'nds-unlock-lockout' "remote-unlock shutdown configuration.nix"
    assert_contains "$content" 'Type = "simple"' "remote-unlock shutdown configuration.nix"
    assert_contains "$content" 'sleep 120' "remote-unlock shutdown configuration.nix"
    assert_contains "$content" 'after 120 seconds' "remote-unlock shutdown configuration.nix"
    assert_contains "$content" 'poweroff --force --force' "remote-unlock shutdown configuration.nix"
    assert_not_contains "$content" 'reboot --force' "remote-unlock shutdown configuration.nix"
    assert_contains "$content" 'conflicts = [ "initrd-switch-root.service" ]' "remote-unlock shutdown configuration.nix"
    assert_contains "$content" 'ConditionPathExists = "/etc/initrd-release"' "remote-unlock shutdown configuration.nix"
    assert_not_contains "$content" 'crypttabExtraOpts' "remote-unlock shutdown configuration.nix"
    assert_not_contains "$content" 'tries=2' "remote-unlock shutdown configuration.nix"
    assert_not_contains "$content" 'MaxAuthTries' "remote-unlock shutdown configuration.nix"
    assert_not_contains "$content" 'nds-unlock.nft' "remote-unlock shutdown configuration.nix"
    assert_not_contains "$content" 'pkgs.nftables' "remote-unlock shutdown configuration.nix"
    assert_not_contains "$content" 'before = [ "initrd-switch-root.service" ]' "remote-unlock shutdown configuration.nix"
    assert_not_contains "$content" '@@TIMEOUT@@' "remote-unlock shutdown configuration.nix"

    rm -rf "$tmp_dir"

    # Values below 30s are off (not a short timer).
    tmp_dir=$(mktemp -d)
    output="${tmp_dir}/configuration.nix"
    _nds_test_seed_admin_password "$tmp_dir"

    _nds_test_reset_encryption_vars
    CONFIG_DATA[ENCRYPTION]="true"
    CONFIG_DATA[ENCRYPTION_PASSWORD]="true"
    CONFIG_DATA[ENCRYPTION_KEY]="false"
    CONFIG_DATA[ENCRYPTION_REMOTE_UNLOCK]="true"
    CONFIG_DATA[ENCRYPTION_REMOTE_SSH_KEY]="ssh-ed25519 AAAAfakeKey test@host"
    CONFIG_DATA[ENCRYPTION_REMOTE_NETWORK]="dhcp"
    CONFIG_DATA[ENCRYPTION_REMOTE_SHUTDOWN]="15"

    nds_nixcfg_build_classic_auto
    nds_nixcfg_write "$output"

    content=$(<"$output")
    assert_not_contains "$content" 'nds-unlock-lockout' "remote-unlock shutdown-15 configuration.nix"
    assert_not_contains "$content" 'sleep 15' "remote-unlock shutdown-15 configuration.nix"

    rm -rf "$tmp_dir"
    if [[ -n "$_sv_save" ]]; then
        export NDS_NIXOS_STATE_VERSION="$_sv_save"
    else
        unset NDS_NIXOS_STATE_VERSION
    fi
}
