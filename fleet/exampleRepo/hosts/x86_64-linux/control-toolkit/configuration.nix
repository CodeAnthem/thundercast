# ==================================================================================================
# exampleRepo - control-toolkit
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date: Created: 2026-08-19 | Modified: 2026-09-01
# Description: Existing ops VM host — toolkit action installs this folder
# ==================================================================================================

{ inputs, ... }: {
  imports = [
    (inputs.thundercast.nixosModules.host { hostDir = ./.; })
    inputs.thundercast.nixosModules.toolkit
    inputs.thundercast.nixosModules.tcast
    ./opts.nix
  ];

  programs.tcast.enable = true;

  networking.hostName = "control-toolkit";
  system.stateVersion = "24.11";
}
