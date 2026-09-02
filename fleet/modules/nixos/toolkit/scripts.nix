# ==================================================================================================
# ThunderCast - NixOS installer and operator toolkit by CodeAnthem
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date: Created: 2026-08-19 | Modified: 2026-09-01
# Description: fleet/toolkit checkout location — opts.nixos.toolkit.scripts
# ==================================================================================================

{ config, lib, my, ... }: with lib; with my.lib; let
# ==================================================================================================
# ModuleVariables
# ==================================================================================================
  optionPath = mkOptionPath [ "toolkit" "scripts" ];


in {
# ==================================================================================================
# Options
# ==================================================================================================
  options = lib.setAttrByPath optionPath {
    dest = mkOpt types.str "/var/lib/nds-toolkit" "Checkout root (current/ -> fleet/toolkit)";
    repo = mkOpt types.str "https://github.com/CodeAnthem/thundercast.git" "Git URL for fleet toolkit";
    branch = mkOpt types.str "main" "Branch toolkit-update tracks";
    sparsePath = mkOpt types.str "fleet/toolkit" "Subdirectory inside the repo";
    leafDir = mkOpt types.str "/var/lib/nds-toolkit/leaf" "Operator leaf git clone (not /etc/nixos)";
    leafRepo = mkOpt types.str "" "Leaf git URL. Empty = set per host";
    leafBranch = mkOpt types.str "main" "Leaf branch toolkit commits/pushes";
  };
}
