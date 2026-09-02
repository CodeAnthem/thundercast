# ==================================================================================================
# ThunderCast - NixOS installer and operator toolkit by CodeAnthem
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date: Created: 2026-06-26 | Modified: 2026-08-20
# Description: Control toolkit packages — opts.nixos.toolkit.tools
# ==================================================================================================

{ config, lib, my, pkgs, ... }: with lib; with my.lib; let
# ==================================================================================================
# ModuleVariables
# ==================================================================================================
  optionPath = mkOptionPath [ "toolkit" "tools" ];
  cfg = lib.attrByPath optionPath {} config;


in {
# ==================================================================================================
# Options
# ==================================================================================================
  options = lib.setAttrByPath optionPath {
    enable = lib.mkEnableOption "ops toolkit packages for control VMs";
    extraPackages = mkOpt (types.listOf types.package) [] "Additional packages";
  };


# ==================================================================================================
# Config
# ==================================================================================================
  config = lib.mkIf (cfg.enable or false) {
    environment.systemPackages = with pkgs; [
      git
      jq
      yq-go
      sops
      age
      ssh-to-age
      openssh
      curl
      wget
      nmap
      htop
    ] ++ cfg.extraPackages;
  };
}
