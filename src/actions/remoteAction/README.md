# Remote action

Pick **remoteAction**, then NDS asks for an **action catalog** (any git repo with `.nds/actions/*.sh` or `.nds/action.sh`). Default URL is Thundercast. After clone you pick an action from that catalog; NDS then loads it like a builtin (preview + settings manager).

**Do not run unknown remote actions.** Scripts under `.nds/actions/` are `source`d into the NDS shell with installer privileges. NDS asks you to confirm **before** that source; the action preview repeats the warning.

**installFlake** is for a named host that already exists. Catalog actions (Thundercast: **addRole**, **toolkit**) decide what happens after clone.

## Flow

1. Main menu → **remoteAction**
2. Catalog Git URL (default Thundercast, or your own repo)
3. Catalog clones over **HTTPS when the repo is public**. Thundercast is **private**, so the default URL runs the **git SSH wizard**.
4. Pick an action from `.nds/actions/`
5. **Confirm before load** (orange warning — the catalog script is not sourced yet)
6. Preview (orange warning) → settings (install flake URL, Network hostname, disk, …)
7. Clone the install flake, pick a role, and run the action

## Settings

| Key | Meaning |
|-----|---------|
| `CAST_REPO_URL` | Catalog git URL (asked before settings). Default: `https://github.com/CodeAnthem/thundercast.git` |
| `CAST_ACTION` | Action id from `.nds/actions/<id>.sh`. Interactive: catalog menu. Unattended: `NDS_CAST_ACTION`, or empty + `FLAKE_REPO_URL` → **addRole**. |
| `CAST_TOOLKIT_MODE` | `new` or `restore` (Thundercast toolkit) |
| `CAST_TOOLKIT_BUNDLE` | Path to bundle zip (restore) |
| `FLAKE_REPO_URL` | **Install flake** (your NixOS config repo) |
| `NETWORK_HOSTNAME` | Machine hostname (Network preset). Copied to `FLAKE_HOST` for a new host. |
| `SOPS_AGE_REUSE` | `generate` or `file` (reinstall) |
| `SOPS_AGE_KEY_FILE` | Existing machine `keys.txt` when reuse=file |

Hostname lives in the **Network** category. Flake path / host-dir / hardware placement stay at their defaults unless you set `NDS_FLAKE_*`.

A private catalog URL (`git@…` or private `https://`) uses the git SSH wizard. Public `https://` catalogs clone without a key.

## Discovery

1. Clone catalog → `.nds/actions/*.sh` + optional `manifest`
2. Pick the action (own menu, like the builtin action list)
3. Settings manager for that action
4. Clone the install flake (write access required when the action pushes)
5. Leaf `.nds/action.sh` may override **addRole** only (not toolkit)
