# ==================================================================================================
# exampleRepo - Private cluster leaf template
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-17 | Modified: 2026-08-20
# Description:   Copy to a private git remote; NDS remoteAction installs from .roles/ + existing hosts
# ==================================================================================================

{
  description = "Private cluster leaf on Thunderstorm (template)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    thunderstorm.url = "git+ssh://git@github.com/CodeAnthem/thunderstorm.git";
    thunderstorm.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.follows = "thunderstorm/home-manager";

    thundercast.url = "github:CodeAnthem/thundercast";

    comin.url = "github:nlewo/comin";
    comin.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
  };

  outputs = inputs@{ self, nixpkgs, thunderstorm, ... }:
    let
      flakeTools = thunderstorm.lib;
      setup = {
        id = {
          key           = "mycluster";
          name          = "My Cluster";
          namespace     = "mc";
          author        = "you";
          description   = "Private infra leaf";
          version       = "0.1.0";
          repository    = "git+ssh://git@github.com/you/mycluster.git";
          source        = ./.;
        };
        settings  = import ./setup/settings.nix (flakeTools // { inherit inputs; });
        overrides = import ./setup/overrides.nix;
        dev = {
          settings  = import ./setup/settingsDev.nix;
          overrides = import ./setup/overridesDev.nix;
        };
      };
    in
      thunderstorm.lib.compose setup;
}
