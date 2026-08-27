# Remote action

Pick **remoteAction** for **your** catalog — a git repo with `.nds/actions/*.sh` (or `.nds/action.sh`). ThunderCast’s own `.nds/actions/addRole.sh` and `toolkit.sh` are stubs: **addRole** and **toolkit** are built-in NDS actions (`NDS_ACTION=addRole` / `NDS_ACTION=toolkit`). A catalog that only has those stubs fails closed after clone.

**Do not run unknown remote actions.** Scripts under `.nds/actions/` are `source`d into the NDS shell with installer privileges. NDS asks you to confirm **before** that source.

**installFlake** is for a named host that already exists. **addRole** scaffolds a new host from `.roles/`. **toolkit** creates or restores the ops VM. Catalog scripts compose host files, then Part A installs (unless `NDS_REMOTE_ACTION_DID_INSTALL=1`).

`remote_action_run` must **compose only** (write flake files, register secrets as `*_FILE` paths). Do not call `nixos-install` unless you set `NDS_REMOTE_ACTION_DID_INSTALL=1` so Part A does not run twice.

## Flow

1. Main menu → **remoteAction**
2. Catalog Git URL (your repo — not ThunderCast builtins)
3. Catalog clones over **HTTPS when the repo is public**
4. Pick an action from `.nds/actions/` (addRole and toolkit are omitted)
5. **Confirm before load** (orange warning — the catalog script is not sourced yet)
6. Preview → settings (install flake URL, disk, …)
7. Disk confirm, then `remote_action_run` (compose), then Part A

## Settings

| Key | Meaning |
|-----|---------|
| `CAST_REPO_URL` | Catalog git URL (asked before settings). Default URL is ThunderCast (public); that clone has **no user actions**. Point this at your leaf or a dedicated catalog repo. |
| `CAST_ACTION` | Action id from `.nds/actions/<id>.sh`. Interactive: catalog menu. Unattended: `NDS_CAST_ACTION` is required (no default to addRole). |
| `FLAKE_REPO_URL` | **Install flake** (your NixOS config repo) |
| `NETWORK_HOSTNAME` | Machine hostname (Network preset). Copied to `FLAKE_HOST` for a new host. |

Hostname lives in the **Network** category. Flake path / host-dir / hardware placement stay at their defaults unless you set `NDS_FLAKE_*`.

A private catalog URL (`git@…` or private `https://`) uses the git SSH wizard. Public `https://` catalogs clone without a key.

## Discovery

1. Clone catalog → `.nds/actions/*.sh` + optional `manifest` (addRole/toolkit skipped)
2. Pick the action
3. Settings manager for that action
4. Clone the install flake (write access required when the action pushes)
5. Leaf `.nds/action.sh` may override the selected user action

Existing-host restore loads `.nds/hosts/<name>.recipe`.
