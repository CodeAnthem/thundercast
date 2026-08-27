# ==================================================================================================
# exampleRepo - control-toolkit
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date: Created: 2026-08-19 | Modified: 2026-08-28
# Description: Existing ops VM host — toolkit action installs this folder
# ==================================================================================================

{ inputs, ... }: {
  imports = [
    (inputs.thundercast.nixosModules.host { hostDir = ./.; })
    ./opts.nix
  ];
  networking.hostName = "control-toolkit";
  system.stateVersion = "24.11";
}
