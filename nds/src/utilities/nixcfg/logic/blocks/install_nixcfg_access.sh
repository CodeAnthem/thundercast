#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-08-14
# Description:   NixOS Config Generation - Access Module
# Feature:       Admin user, sudo, and SSH configuration for NixOS
# ==================================================================================================

# =============================================================================
# NIXOS CONFIG GENERATION - Public API
# ==================================================================================================

# Description: SHA-512 crypt hash for NixOS initialHashedPassword (not reversible to the password).
# Arguments:
# - pw: <String> Plaintext password
# Returns:
# - <String> $6$... hash on stdout
_nds_nixcfg_hash_password() {
    local pw="$1" hashed
    [[ -n "$pw" ]] || return 1
    if command -v openssl &>/dev/null; then
        hashed=$(printf '%s' "$pw" | openssl passwd -6 -stdin) || return 1
    elif command -v mkpasswd &>/dev/null; then
        hashed=$(printf '%s' "$pw" | mkpasswd -m sha-512 --stdin) || return 1
    else
        error "Need openssl or mkpasswd to hash the admin password"
        return 1
    fi
    [[ "$hashed" == \$6\$* ]] || {
        error "Password hash generation produced an unexpected result"
        return 1
    }
    printf '%s' "$hashed"
}

# Description: Emit the users/sudo/SSH NixOS module (password required).
nds_nixcfg_access() {
    local admin_user="${1:-admin}"
    local sudo_password="${2:-true}"
    local ssh_enable="${3:-true}"
    local ssh_port="${4:-22}"
    local ssh_pw_auth="${5:-true}"
    local admin_ssh_key="${6:-}"
    local admin_password="${7:-}"

    if [[ -z "$admin_password" ]]; then
        error "Admin password is required (no default)"
        return 1
    fi
    _nds_nixcfg_access_generate "$admin_user" "$sudo_password" "$ssh_enable" "$ssh_port" "$ssh_pw_auth" "$admin_ssh_key" "$admin_password"
}

# =============================================================================
# NIXOS CONFIG GENERATION - Implementation
# ==================================================================================================

_nds_nixcfg_access_generate() {
    local admin_user="$1"
    local sudo_password="$2"
    local ssh_enable="$3"
    local ssh_port="$4"
    local ssh_pw_auth="$5"
    local admin_ssh_key="$6"
    local admin_password="$7"

    if [[ -z "$admin_password" ]]; then
        error "Admin password is required (no default)"
        return 1
    fi

    local escaped_pw ssh_pw_nix hashed_pw
    hashed_pw="${ _nds_nixcfg_hash_password "$admin_password"; }" || return 1
    escaped_pw=${ _nds_nixcfg_nix_escape "$hashed_pw"; }
    ssh_pw_nix="false"
    [[ "$ssh_pw_auth" == "true" ]] && ssh_pw_nix="true"

    local key_block=""
    if [[ -n "$admin_ssh_key" ]]; then
        local escaped_key
        escaped_key=${ _nds_nixcfg_nix_escape "$admin_ssh_key"; }
        key_block=$'\n  openssh.authorizedKeys.keys = [ "'"${escaped_key}"'" ];'
    fi

    # Quoted heredoc + @@TOKEN@@ substitution: no bash expansion, no escaping.
    # User-controlled values (key block, password) filled last.
    local block
    block=$(nds_nixcfg_subst "$(cat <<'EOF'
# Admin User
users.users.@@ADMIN_USER@@ = {
  isNormalUser = true;
  description = "@@ADMIN_USER@@";
  extraGroups = [ "wheel" "networkmanager" ];
  initialHashedPassword = "@@PASSWORD@@";@@KEY_BLOCK@@
};

# Sudo Configuration
security.sudo.wheelNeedsPassword = @@SUDO_PASSWORD@@;

# SSH Configuration
services.openssh = {
  enable = @@SSH_ENABLE@@;
  ports = [ @@SSH_PORT@@ ];
  settings = {
    PasswordAuthentication = @@SSH_PW_NIX@@;
    PermitRootLogin = "no";
    X11Forwarding = false;
  };
};
EOF
)" @@ADMIN_USER@@ "$admin_user" @@SUDO_PASSWORD@@ "$sudo_password" @@SSH_ENABLE@@ "$ssh_enable" @@SSH_PORT@@ "$ssh_port" @@SSH_PW_NIX@@ "$ssh_pw_nix" @@KEY_BLOCK@@ "$key_block" @@PASSWORD@@ "$escaped_pw")

    nds_nixcfg_register "access" "$block" 40
}
