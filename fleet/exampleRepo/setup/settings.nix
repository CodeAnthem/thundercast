# ==================================================================================================
# exampleRepo - Private cluster leaf template
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-17 | Modified: 2026-08-20
# Description:   Hosts fileStore + leaf-owned extraModules
# ==================================================================================================

{ mkNode, inputs, ... }: {
  fileStore = {
    nodes = [
      (mkNode {
        name = "hosts";
        type = "nixosConfig";
        path = "hosts";
        method = "host";
        description = "Machine configurations";
      })
    ];
  };
  nixos = {
    extraSpecialArgs = { inherit inputs; };
    extraModules = [
      inputs.comin.nixosModules.comin
      inputs.sops-nix.nixosModules.sops
      inputs.disko.nixosModules.disko
      inputs.nixos-facter-modules.nixosModules.facter
      inputs.home-manager.nixosModules.home-manager
      inputs.thundercast.nixosModules.toolkit
    ];
  };
}
