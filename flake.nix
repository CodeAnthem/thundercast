{
  description = "ThunderCast — NixOS installer (NDS) and operator toolkit";

  outputs = { self }: {
    nixosModules.toolkit = {
      imports = [
        ./modules/nixos/toolkit/ops.nix
        ./modules/nixos/toolkit/scripts.nix
        ./modules/nixos/toolkit/tools.nix
      ];
    };
  };
}
