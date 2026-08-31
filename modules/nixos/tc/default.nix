# ==================================================================================================
# ThunderCast - NixOS module: host CLI (tc)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date: Created: 2026-08-31 | Modified: 2026-08-31
# Description: Put `tc` + `tc-git-ssh` on PATH; optional GIT_SSH_COMMAND
# ==================================================================================================
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.tc;
  tcPkg = pkgs.callPackage ../../../tc/package.nix { };
in
{
  options.programs.tc = {
    enable = lib.mkEnableOption "ThunderCast host CLI (tc)";
    setGitSshCommand = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Set GIT_SSH_COMMAND to tc-git-ssh for private flake inputs";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ tcPkg ];
    environment.sessionVariables = lib.mkIf cfg.setGitSshCommand {
      GIT_SSH_COMMAND = "${tcPkg}/bin/tc-git-ssh";
    };
  };
}
