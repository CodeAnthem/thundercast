# Remote action

Pick **remoteAction** for **your** catalog — a git repo with `.nds/actions/*.sh` (or `.nds/action.sh`). No ThunderCast default URL: this path exists so others can ship custom install actions **without** opening a PR here.

ThunderCast birth wizards **addFleetHost** and **toolkit** live under `fleet/nds-actions/` and are auto-discovered by NDS. They are **not** catalog stubs and must not be selected via `remoteAction`.

**Do not run unknown remote actions.** Scripts under `.nds/actions/` are `source`d into the NDS shell with installer privileges. NDS asks you to confirm **before** that source.

**installFlake** is for a named host that already exists. **addFleetHost** scaffolds a new host from `.roles/`. **toolkit** creates or restores the ops VM. A catalog action cooks its own groups and may register realize hooks. It does not birth the machine itself.

## Flow

1. Main menu → **remoteAction**
2. Catalog Git URL (**required** — your repo; empty fails closed)
3. Catalog clones over **HTTPS when the repo is public**
4. Pick an action from `.nds/actions/` (addFleetHost and toolkit ids are omitted if present)
5. **Confirm before load** (orange warning — the catalog script is not sourced yet)
6. Preview → settings (install flake URL, disk, …)
7. Confirm, then realize births the machine from the sealed recipe

## Settings

| Key | Meaning |
|-----|---------|
| `CAST_REPO_URL` | Catalog git URL (required). No ThunderCast default. |
| `CATALOG_ACTION` | Action id under `.nds/actions/<id>/setup.sh`. Interactive: catalog menu. Unattended: `NDS_CATALOG_ACTION` is required. |
| `FLAKE_REPO_URL` | **Install flake** (your NixOS config repo) |
| `NETWORK_HOSTNAME` | Machine hostname (Network preset). Copied to `FLAKE_HOST` for a new host. |

Hostname lives in the **Network** category. Flake path / host-dir / hardware placement stay at their defaults unless you set `NDS_FLAKE_*`.

A private catalog URL (`git@…` or private `https://`) uses the git SSH wizard. Public `https://` catalogs clone without a key.

## Discovery

1. Clone catalog → `.nds/actions/*.sh` + optional `manifest`
2. Pick the action
3. Settings manager for that action
4. Clone the install flake (write access required when the action pushes)
5. Leaf `.nds/action.sh` may override the selected user action

Existing-host restore loads `.nds/hosts/<name>.recipe`.
