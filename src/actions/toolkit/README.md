# toolkit

First-class NDS action: create or restore an **ops VM**, then Part A flake-install. **Local only** — nixos-anywhere cannot receive operator keys yet.

Not a catalog script. ThunderCast `.nds/actions/toolkit.sh` is a stub that fails closed.

```bash
export NDS_ACTION=toolkit
sudo -E bash src/app/main.sh
```

## Role vs host

`.roles/toolkit/` is the **opts template** (and optional `nds.sh` / `hooks/`). Hardware is **per host folder** — two ops VMs (VMware vs KVM, another hypervisor) are two host dirs, one shared `.toolkit/` git tree, one operator private key copied onto each VM (`CAST_TOOLKIT_MODE=restore` on the second).

`addRole` skips `toolkit` so it does not show in the Swarm role menu. Extra ops VMs use this action with a different `FLAKE_HOST`.

## You need

- A leaf with `.roles/toolkit/` (copied from exampleRepo). If `hosts/<system>/<FLAKE_HOST>/` is missing, compose scaffolds it from that role.
- **Write** Git access
- `INSTALL_MODE=local` (remote is refused)

Default host name is `control-toolkit`. The wizard asks; override with `NDS_FLAKE_HOST`.

## Modes

UI: **Restore existing toolkit?** (default no). Recipes/env still use `CAST_TOOLKIT_MODE`.

| `CAST_TOOLKIT_MODE` | What happens |
|---------------------|----------------|
| `new` | Generate operator age + toolkit SSH. Commit **public** keys only. Private keys go to the install bundle and `/mnt`. First ops VM only. |
| `restore` | Inject a previous bundle zip (`CAST_TOOLKIT_BUNDLE`) — same operator private on another ops VM |

The settings menu has one **Toolkit** category (host + flake URL + restore). Disk / encryption stay separate. `installFlake` stays enabled for defaults (install path, sops, hardware) but is not a second menu.

## Flow

1. Refuse if `INSTALL_MODE=remote`
2. Clone leaf (write probe)
3. Settings menu → disk confirm → compose (pubs + recipe; scaffold host if missing) → push
4. Part A local flake-install
5. Copy age/SSH secrets and seed `toolkitScripts` onto `/mnt`

After boot: `toolkit` menu, `tc-sops`, `toolkit-update` (tools fetch — not `nixos-rebuild` / comin).

## Hooks

`nds_hook_load` order (unchanged):

1. `.nds/lib` (functions only)
2. ThunderCast `src/actions/toolkit/hooks/`
3. `.nds/toolkit/`
4. `.nds/common/`
5. `.roles/toolkit/hooks/` because `SCAFFOLD_ROLE=toolkit`

Leaf skeleton: [exampleRepo](../../../exampleRepo/README.md).
