# toolkit

First-class NDS action: create or restore the **ops VM**, then Part A flake-install. **Local only** — nixos-anywhere cannot receive operator keys yet.

Not a catalog script. Fleet birth wizard — auto-loaded with NDS (`fleet/nds-actions/`). Do not use `remoteAction` for this.

```bash
export NDS_ACTION=toolkit
sudo -E bash nds/src/app/main.sh
```

## You need

- A leaf that **already has** the toolkit host folder (`hosts/x86_64-linux/control-toolkit/`). This action does not scaffold from `.roles/`. Host is `control-toolkit` unless `NDS_FLAKE_HOST` is set.
- **Write** Git access
- `INSTALL_MODE=local` (remote is refused)

A second ops VM (another hypervisor): copy that host folder, set `NDS_FLAKE_HOST`, turn **Restore** on. Shared git `.toolkit/`, same operator key, different `nds_generated.nix`.

## Modes

UI: **Restore existing toolkit?** (default no). Recipes/env still use `CAST_TOOLKIT_MODE`.

| `CAST_TOOLKIT_MODE` | What happens |
|---------------------|----------------|
| `new` | Generate operator age + toolkit SSH. Commit **public** keys only. Private keys go to the install bundle and `/mnt`. |
| `restore` | Inject a previous bundle zip (`CAST_TOOLKIT_BUNDLE`) |

The settings menu has one **Toolkit** category (flake URL + restore). Disk / encryption stay separate. `installFlake` stays enabled for defaults (install path, sops, hardware) but is not a second menu.

## Flow

1. Refuse if `INSTALL_MODE=remote`
2. Clone leaf (write probe)
3. Settings menu → disk confirm → compose (pubs + recipe) → push
4. Part A local flake-install
5. Copy age/SSH secrets and seed `fleet/toolkit` onto `/mnt`

After boot: `toolkit` menu, `tc-sops`, `toolkit-update` (tools fetch — not `nixos-rebuild` / comin).

ISO hooks: leaf `.nds/hooks/toolkit/*.sh` plus ThunderCast `fleet/nds-actions/toolkit/hooks/` (operator pubs go to `.toolkit/operator/`).

Leaf skeleton: [exampleRepo](../../exampleRepo/README.md).
