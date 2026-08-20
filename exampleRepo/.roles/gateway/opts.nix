# Template gateway — drained worker; leaf adds Traefik/CoreDNS
{
  opts.nixos.nix.defaults.enable = true;
  opts.nixos.nix.stateVersion.enable = true;
  opts.nixos.ssh.enable = true;
  opts.nixos.security.firewall.enable = true;
  opts.nixos.security.firewall.swarm = true;
  opts.nixos.security.hardening.enable = true;
  opts.nixos.virtualisation.docker.enable = true;
  opts.nixos.virtualisation.swarm = {
    enable = true;
    role = "worker";
    drain = true;
    managerAddr = "192.0.2.11:2377";
    labels = [ "role=gateway" "edge=true" ];
  };
}
