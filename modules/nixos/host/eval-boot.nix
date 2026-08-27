# ==================================================================================================
# ThunderCast - NixOS installer and operator toolkit by CodeAnthem
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date: Created: 2026-08-28 | Modified: 2026-08-28
# Description: QEMU / off-device eval stub — NOT for real installs
# ==================================================================================================

{ lib, modulesPath, ... }: {
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.loader.grub = {
    enable = lib.mkDefault true;
    device = lib.mkDefault "nodev";
  };
}
