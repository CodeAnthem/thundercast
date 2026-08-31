# ==================================================================================================
# ThunderCast - NixOS module: host CLI (tcast)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date: Created: 2026-08-31 | Modified: 2026-09-01
# Description: Put `tcast` + `tcast-git-ssh` on PATH for all users; shared /var/lib/tcast
# Note: Binary is `tcast` — not `tc` (iproute2 traffic control already owns `tc`).
# ==================================================================================================
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.tcast;
  tcastPkg = pkgs.callPackage ../../../TC-Tools/package.nix { };
in
{
  options.programs.tcast = {
    enable = lib.mkEnableOption "ThunderCast host CLI (tcast)";
    setGitSshCommand = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Set GIT_SSH_COMMAND to tcast-git-ssh for private flake inputs";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ tcastPkg ];
    environment.sessionVariables = lib.mkIf cfg.setGitSshCommand {
      GIT_SSH_COMMAND = "${tcastPkg}/bin/tcast-git-ssh";
      TCAST_GIT_SSH_MAP = "/var/lib/tcast/git.map";
    };
    systemd.tmpfiles.rules = [
      "d /var/lib/tcast 0755 root root -"
    ];
  };
}
