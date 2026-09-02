{
  description = "ThunderCast — NDS installer, tcast host CLI, and fleet (toolkit + leaf)";

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
        tcast = pkgs.callPackage ./tcast/package.nix { };
      in
      {
        inherit tcast;
        default = tcast;
      }
    );

    nixosModules.host = import ./fleet/modules/nixos/host;
    nixosModules.tcast = import ./tcast/modules/tcast;
    nixosModules.toolkit = {
      imports = [
        ./fleet/modules/nixos/toolkit/ops.nix
        ./fleet/modules/nixos/toolkit/scripts.nix
        ./fleet/modules/nixos/toolkit/tools.nix
      ];
    };

    # Convenience alias
    nixosModules.hostCli = self.nixosModules.tcast;
  };
}
