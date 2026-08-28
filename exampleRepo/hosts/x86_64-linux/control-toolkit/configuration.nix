# ==================================================================================================
# exampleRepo - control-toolkit
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date: Created: 2026-08-19 | Modified: 2026-08-28
# Description: Existing ops VM host — toolkit action / .roles/toolkit
# ==================================================================================================

{ inputs, ... }: {
  imports = [
    (inputs.thundercast.nixosModules.host { hostDir = ./.; })
    inputs.thundercast.nixosModules.toolkit
    ./opts.nix
  ];
  networking.hostName = "control-toolkit";
  system.stateVersion = "24.11";
}
