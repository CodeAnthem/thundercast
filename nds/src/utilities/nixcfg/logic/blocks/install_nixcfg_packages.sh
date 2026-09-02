#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-14 | Modified: 2026-08-14
# Description:   NixOS Config Generation - System packages
# Feature:       environment.systemPackages plus vanilla program hints
# ==================================================================================================

# Description: Register the packages section (empty list + commented examples).
_nds_nixcfg_packages_generate() {
    local block
    block=$(cat <<'EOF'
environment.systemPackages = with pkgs; [
  # vim
  # wget
];

# Some programs need SUID wrappers, can be configured further or are
# started in user sessions.
# programs.mtr.enable = true;
# programs.gnupg.agent = {
#   enable = true;
#   enableSSHSupport = true;
# };
EOF
)

    nds_nixcfg_register "packages" "$block" 50
}
