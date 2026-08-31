# ThunderCast host CLI (`TC-Tools`)

NDS-free tools for any NixOS host. **Source tree:** `TC-Tools/`. **Command name:** `tcast`  
(not `tc` — that is already [iproute2 traffic control](https://man.archlinux.org/man/tc.8)).

## Layout

```
TC-Tools/
  bin/tcast
  bin/tcast-git-ssh      # GIT_SSH_COMMAND entry (real argv0)
  lib/                   # shared helpers only
  commands/              # one file per command
  package.nix
```

## Durable host config (`/var/lib/tcast`)

| Path | Purpose |
|------|---------|
| `/var/lib/tcast/switch.conf` | flake root / host attr / ref |
| `/var/lib/tcast/clean.conf` | GC defaults |
| `/var/lib/tcast/git.map` | deploy-key map (`owner/repo` → key path) |

Keys stay under `/root/.ssh/nds_deploy_*`. Map is app config, not under `~/.ssh/`.

## Commands

```bash
tcast switch                 # pull + nixos-rebuild
tcast switch --force         # discard local dirty/ahead; match remote then rebuild
tcast switch --config        # map + flake settings
tcast restore                # menu of NixOS system generations
tcast clean [--config]
tcast status
sudo tcast …
```

## Install

```nix
imports = [ inputs.thundercast.nixosModules.tcast ];
# or: environment.systemPackages = [ inputs.thundercast.packages.${pkgs.system}.tcast ];
```

## Test only TC-Tools

```bash
./TC-Tools/bin/tcast help
nix build .#tcast && ./result/bin/tcast version
```
