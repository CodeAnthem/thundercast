# ==================================================================================================
# ThunderCast - NixOS installer and operator toolkit by CodeAnthem
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date: Created: 2026-08-28 | Modified: 2026-08-28
# Description: Per-host NDS contract — facter / hardware-configuration.nix / toolkit SSH pub
# ==================================================================================================
#
# Leaf: imports = [ (inputs.thundercast.nixosModules.host { hostDir = ./.; }) ];
# Expects hosts/<system>/<name>/ (three levels below the flake root).

hostDir:
{ config, lib, ... }:
let
  inherit (lib) mkIf optional optionals;

  gitignored = path:
    import (builtins.path {
      inherit path;
      name = "host-" + builtins.baseNameOf path;
    });

  facter = hostDir + "/facter.json";
  hardwareNix = hostDir + "/hardware-configuration.nix";
  bootCommitted = hostDir + "/boot.nix";
  generated = hostDir + "/nds_generated.nix";
  flakeRoot = dirOf (dirOf (dirOf hostDir));
  toolkitSsh = flakeRoot + "/.toolkit/operator/keys/ssh.pub";
  sshPub = if builtins.pathExists toolkitSsh then toolkitSsh else null;

  hasFacter = builtins.pathExists facter;
  hasHardwareNix = builtins.pathExists hardwareNix;
  hasBoot = builtins.pathExists bootCommitted || builtins.pathExists generated;
  needEvalStub = !hasFacter && !hasHardwareNix && !hasBoot;

  sshEnabled = lib.attrByPath [ "opts" "nixos" "ssh" "enable" ] false config;
in {
  imports =
    (optional (hasHardwareNix && !hasFacter) (gitignored hardwareNix))
    ++ (optional needEvalStub ./eval-boot.nix);

  hardware.facter.reportPath = mkIf hasFacter (builtins.path {
    path = facter;
    name = "facter.json";
  });

  opts.nixos.ssh.authorizedKeys = mkIf sshEnabled (
    optionals (sshPub != null) [ (lib.fileContents sshPub) ]
  );
}
