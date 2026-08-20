#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-30 | Modified: 2026-07-02
# Description:   LUKS unlock Nix config (keyfile on USB; no embedded key)
# Feature:       Emits keyFile / fallbackToPassword / systemd mount options.
#                The LUKS device UUID comes from hardware-configuration.nix
#                (auto-generated), so this block only adds unlock behavior.
# ==================================================================================================

# Modes:
#   password only  -> no extra config (NixOS prompts at boot / via initrd SSH)
#   key only (raw) -> keyFile = USB device, keyFileSize, keyFileTimeout
#   key only (file)-> systemd mount of USB + keyFile = file on mount, keyFileTimeout
#   both (raw)     -> keyFile + fallbackToPassword + short keyFileTimeout
#   both (file)    -> systemd mount + keyFile + fallbackToPassword
_nds_nixcfg_luks_generate() {
    local use_password="$1"
    local use_key="$2"
    local key_device="$3"
    local key_file="$4"
    local key_length="$5"

    local timeout
    if [[ "$use_password" == "true" ]]; then
        # Both: try the key briefly, then fall back to a password prompt.
        timeout=10
    else
        # Key only: give the USB more time to settle, no fallback.
        timeout=30
    fi

    local block=""
    local mount_block=""

    # File-on-filesystem: mount the USB in the initrd before reading the key.
    if [[ -n "$key_file" ]]; then
        mount_block=$(nds_nixcfg_subst "$(cat <<'EOF'
# Mount the USB stick holding the LUKS keyfile before unlock
boot.initrd.systemd.mounts = [{
  what = "@@KEY_DEVICE@@";
  where = "/mnt-keyusb";
  type = "auto";
}];
EOF
)" @@KEY_DEVICE@@ "$key_device")
        local key_path="/mnt-keyusb/${key_file}"
        # Strip a leading slash from the user-provided file path to avoid //.
        key_path="/mnt-keyusb/${key_file#/}"
    else
        # Raw device: key bytes read directly from the block device.
        local key_path="${key_device}"
    fi

    if [[ "$use_password" == "true" ]]; then
        if [[ -n "$key_file" ]]; then
            block=$(nds_nixcfg_subst "$(cat <<'EOF'
@@MOUNT_BLOCK@@

# LUKS unlock: keyfile on mounted USB, fall back to password prompt
boot.initrd.luks.devices."cryptroot" = {
  keyFile = "@@KEY_PATH@@";
  keyFileTimeout = @@TIMEOUT@@;
  fallbackToPassword = true;
};
EOF
)" @@KEY_PATH@@ "$key_path" @@TIMEOUT@@ "$timeout" @@MOUNT_BLOCK@@ "$mount_block")
        else
            block=$(nds_nixcfg_subst "$(cat <<'EOF'
@@MOUNT_BLOCK@@

# LUKS unlock: raw keyfile on USB device, fall back to password prompt
boot.initrd.luks.devices."cryptroot" = {
  keyFile = "@@KEY_PATH@@";
  keyFileSize = @@KEY_LENGTH@@;
  keyFileTimeout = @@TIMEOUT@@;
  fallbackToPassword = true;
};
EOF
)" @@KEY_PATH@@ "$key_path" @@KEY_LENGTH@@ "$key_length" @@TIMEOUT@@ "$timeout" @@MOUNT_BLOCK@@ "$mount_block")
        fi
    else
        if [[ -n "$key_file" ]]; then
            block=$(nds_nixcfg_subst "$(cat <<'EOF'
@@MOUNT_BLOCK@@

# LUKS unlock: keyfile on mounted USB (no password fallback)
boot.initrd.luks.devices."cryptroot" = {
  keyFile = "@@KEY_PATH@@";
  keyFileTimeout = @@TIMEOUT@@;
};
EOF
)" @@KEY_PATH@@ "$key_path" @@TIMEOUT@@ "$timeout" @@MOUNT_BLOCK@@ "$mount_block")
        else
            block=$(nds_nixcfg_subst "$(cat <<'EOF'
@@MOUNT_BLOCK@@

# LUKS unlock: raw keyfile on USB device (no password fallback)
boot.initrd.luks.devices."cryptroot" = {
  keyFile = "@@KEY_PATH@@";
  keyFileSize = @@KEY_LENGTH@@;
  keyFileTimeout = @@TIMEOUT@@;
};
EOF
)" @@KEY_PATH@@ "$key_path" @@KEY_LENGTH@@ "$key_length" @@TIMEOUT@@ "$timeout" @@MOUNT_BLOCK@@ "$mount_block")
        fi
    fi

    nds_nixcfg_register "luks" "$block" 12
}
