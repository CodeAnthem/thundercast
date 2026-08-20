# Disko CLI config (plain attrset). Do not use `{ config, pkgs, ... }:` —
# `disko --mode disko` imports this file without those arguments.
let
  params = import ./params.nix;
  disk = params.disk;
  fsType = params.fsType or "btrfs";
  encrypt = if builtins.hasAttr "encrypt" params then params.encrypt else true;
  unlockMode = params.unlockMode or "manual"; # manual|dropbear|tpm|keyfile (partition shape only cares about dropbear)
  swapSizeMi = params.swapSize or 0;
  separateHome = params.separateHome or false;
  homeSize = params.homeSize or "20G";
  bootLoader = params.bootLoader or "systemd-boot";
  # systemd-boot / rEFInd keep kernels on the ESP. GRUB UEFI uses ext4 /boot + ESP at /boot/efi.
  espAtBoot = bootLoader != "grub";

  mkFs = type: {
    type = "filesystem";
    format = type;
  };

  mkFsMnt = type: mnt: extraArgs: (mkFs type) // {
    mountpoint = mnt;
    extraArgs = extraArgs;
  };

  bootParts =
    if espAtBoot then {
      esp = {
        size = "1G";
        type = "EF00";
        content = mkFsMnt "vfat" "/boot" [ "-n" "boot" ];
      };
    } else {
      esp = {
        size = "512M";
        type = "EF00";
        content = mkFsMnt "vfat" "/boot/efi" [ "-n" "EFI" ];
      };
      boot = {
        size = "512M";
        type = "8300";
        content = mkFsMnt "ext4" "/boot" [ "-L" "boot" ];
      };
    };

in {
  disko.devices.disk.main = {
    device = disk;
    type = "disk";
    content = {
      type = "gpt";
      partitions =
        let
          withSwap = if swapSizeMi > 0 then bootParts // {
            swap = {
              size = toString swapSizeMi + "M";
              type = "8200";
              content = { type = "swap"; }; # disko uses content.type=swap
            };
          } else bootParts;

          rootPart = {
            size = "100%";
            content = if encrypt then {
              type = "luks";
              name = "cryptroot";
              content = mkFsMnt fsType "/" [ "-L" "nixos" ];
            } else (mkFsMnt fsType "/" [ "-L" "nixos" ]);
          };

          homePart = if separateHome then {
            # Reserve from the tail by setting root smaller would be ideal, but
            # simple approach: rely on 100% root and create home inside FS (btrfs subvol suggested).
            # For separate partition scenarios, user can provide a custom disko file.
          } else {};

        in withSwap // { root = rootPart; } // homePart;
    };
  };
}
