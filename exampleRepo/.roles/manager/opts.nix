# Template manager — first node sets bootstrap; later managers join from sops
{
  opts.nixos.nix.defaults.enable = true;
  opts.nixos.nix.stateVersion.enable = true;
  opts.nixos.ssh.enable = true;
  opts.nixos.security.firewall.enable = true;
  opts.nixos.security.firewall.swarm = true;
  opts.nixos.security.hardening.enable = true;
  opts.nixos.virtualisation.docker.enable = true;
  opts.nixos.virtualisation.docker.listenTcp = true;
  opts.nixos.virtualisation.swarm = {
    enable = true;
    role = "manager";
    bootstrap = true;
    labels = [ "role=manager" ];
  };
}
