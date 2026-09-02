# Template worker — enable swarm.cluster in your leaf when a manager exists
{
  opts.nixos.nix.defaults.enable = true;
  opts.nixos.nix.stateVersion.enable = true;
  opts.nixos.ssh.enable = true;
  opts.nixos.security.firewall.enable = true;
  opts.nixos.security.hardening.enable = true;
  opts.nixos.virtualisation.docker.enable = true;
  opts.nixos.virtualisation.swarm = {
    enable = false;
    role = "worker";
    managerAddr = "192.0.2.10:2377";
    labels = [ "role=worker" ];
  };
}
