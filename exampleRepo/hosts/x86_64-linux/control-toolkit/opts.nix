# Ops VM — toolkit action installs this existing host (not a Swarm role)
{
  opts.nixos.nix.defaults.enable = true;
  opts.nixos.nix.stateVersion.enable = true;
  opts.nixos.ssh.enable = true;
  opts.nixos.toolkit.tools.enable = true;
  opts.nixos.toolkit.ops.enable = true;
  opts.nixos.maintenance.autoUpdate.enable = false;
}
