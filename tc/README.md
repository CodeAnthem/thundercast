# ThunderCast host CLI (`tc`)

NDS-free tools for any NixOS host with a git-backed flake checkout (and optional
per-repo deploy keys).

## Layout

```
tc/
  bin/tc            # dispatcher: tc <command>
  bin/tc-git-ssh    # GIT_SSH_COMMAND entry (must be a real executable)
  lib/              # sourced implementation
  package.nix       # Nix package
  VERSION
```

Not under `src/` — that tree is NDS. Same idea as `toolkitScripts/`.

## Commands

| Command | Purpose |
|---------|---------|
| `tc switch` | `git fetch` + ff-only + `nixos-rebuild switch` |
| `tc clean` | generations + GC |
| `tc status` | host / flake / map summary |
| `tc config` | edit `tc-git.map` (menu or list/add/remove) |
| `tc restore` | save/load map profiles |
| `tc menu` | interactive picker |
| `tc-git-ssh` | pick IdentityFile by `owner/repo` from the map |

## Install

**Flake package / module (preferred):**

```nix
inputs.thundercast.url = "github:CodeAnthem/thundercast";

environment.systemPackages = [ inputs.thundercast.packages.${system}.tc ];
# or:
imports = [ inputs.thundercast.nixosModules.tc ];
```

Update with `nix flake update thundercast` + rebuild. No curl self-update.

**From a checkout (dev / NDS seed):** ensure `tc/bin` is on `PATH`, or run
`./tc/bin/tc status`.

## Private flake inputs

```bash
tc config add owner/repo /absolute/path/to/ed25519
export GIT_SSH_COMMAND=tc-git-ssh
```

Map file: `~/.ssh/tc-git.map` (or `TC_GIT_SSH_MAP`).
