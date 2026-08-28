# Ops VM template — extra keys (laptop) and leaf-specific scripts go here.
# Operator SSH pub is injected from .toolkit/operator/keys/ssh.pub (host module).
# Do not duplicate the operator key.
{
  opts.nixos.profile.id = "toolkit";
  opts.nixos.nix.defaults.enable = true;
  opts.nixos.nix.stateVersion.enable = true;
  opts.nixos.ssh.enable = true;
  opts.nixos.toolkit.tools.enable = true;
  opts.nixos.toolkit.ops.enable = true;
  opts.nixos.maintenance.autoUpdate.enable = false;
}
