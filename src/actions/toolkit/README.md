# toolkit

First-class NDS action: create or restore the **ops VM**, then Part A flake-install. **Local only** — nixos-anywhere cannot receive operator keys yet.

Not a catalog script. ThunderCast `.nds/actions/toolkit.sh` is a stub that fails closed.

```bash
export NDS_ACTION=toolkit
sudo -E bash src/app/main.sh
```

## You need

- A leaf that **already has** the toolkit host folder (example: `hosts/x86_64-linux/control-toolkit/`). This action does not scaffold from `.roles/`.
- **Write** Git access
- `INSTALL_MODE=local` (remote is refused)

## Modes

| `CAST_TOOLKIT_MODE` | What happens |
|---------------------|----------------|
| `new` | Generate operator age + toolkit SSH. Commit **public** keys only. Private keys go to the install bundle and `/mnt`. |
| `restore` | Inject a previous bundle zip (`CAST_TOOLKIT_BUNDLE`) |

## Flow

1. Refuse if `INSTALL_MODE=remote`
2. Clone leaf (write probe)
3. Settings menu → disk confirm → compose (pubs + recipe) → push
4. Part A local flake-install
5. Copy age/SSH secrets and seed `toolkitScripts` onto `/mnt`

After boot: `toolkit` menu, `tc-sops`, `toolkit-update` (tools fetch — not `nixos-rebuild` / comin).

Leaf skeleton: [exampleRepo](../../../exampleRepo/README.md).
