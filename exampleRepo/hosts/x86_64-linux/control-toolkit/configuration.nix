# ==================================================================================================
# exampleRepo - control-toolkit
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date: Created: 2026-08-19 | Modified: 2026-08-19
# Description: Existing ops VM host — toolkit action installs this folder
# ==================================================================================================

{ ... }: {
  imports = [ ./opts.nix ];
  networking.hostName = "control-toolkit";
  system.stateVersion = "24.11";
}
