{
  description = "ThunderCast — NixOS installer (NDS), host CLI (tcast), and operator toolkit";

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
        tcast = pkgs.callPackage ./TC-Tools/package.nix { };
      in
      {
        inherit tcast;
        default = tcast;
      }
    );

    nixosModules.host = import ./modules/nixos/host;
    nixosModules.tcast = import ./modules/nixos/tcast;
    nixosModules.toolkit = {
      imports = [
        ./modules/nixos/toolkit/ops.nix
        ./modules/nixos/toolkit/scripts.nix
        ./modules/nixos/toolkit/tools.nix
      ];
    };

    # Convenience alias
    nixosModules.hostCli = self.nixosModules.tcast;
  };
}
