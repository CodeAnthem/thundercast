{
  description = "ThunderCast — NixOS installer (NDS), host CLI (tc), and operator toolkit";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
  let
    systems = [ "x86_64-linux" "aarch64-linux" ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in
  {
    packages = forAllSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        tc = pkgs.callPackage ./tc/package.nix { };
      in
      {
        inherit tc;
        default = tc;
      }
    );

    nixosModules.host = import ./modules/nixos/host;
    nixosModules.tc = import ./modules/nixos/tc;
    nixosModules.toolkit = {
      imports = [
        ./modules/nixos/toolkit/ops.nix
        ./modules/nixos/toolkit/scripts.nix
        ./modules/nixos/toolkit/tools.nix
      ];
    };

    # Convenience: hostCli ≡ tc module
    nixosModules.hostCli = self.nixosModules.tc;
  };
}
