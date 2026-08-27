# exampleRepo — copy this to your private leaf

NDS clones **your** private git remote as `FLAKE_REPO_URL`, not this folder in-tree. Copy `exampleRepo/` to a new private repository **before** the first toolkit ISO.

- `FLAKE_REPO_URL` — your private leaf (write access on the ISO)
- `NDS_ACTION=toolkit` / `NDS_ACTION=addRole` — built-in NDS actions, not catalog scripts
- `CAST_REPO_URL` — only if **you** ship extra `.nds/actions/` on the leaf (or another repo). ThunderCast has none.

Do **not** install ThunderCast itself as the flake (no real `nixosConfigurations` here).

## Layout

```
flake.nix
setup/
hosts/x86_64-linux/<name>/   # you: configuration.nix + opts.nix; NDS: boot/mounts/guest
.roles/<id>/                 # templates — see .roles/README.md
.toolkit/                    # ops state (pubs, machines/, sops map) — not NDS
.nds/
  <action>/                  # ISO hooks for that action (nds_hook_register)
  common/                    # ISO hooks for every action
  hosts/                     # NDS recipes (disk/encryption defaults; re-askable on restore)
```

## Bootstrap order

1. Copy this tree to a private GitHub repo and `nix flake lock`.
2. ISO → **toolkit** (`NDS_ACTION=toolkit`) → leave Restore off → this leaf URL (write access). Toolkit installs `hosts/…/control-toolkit/` (create that host in git first). Local install only.
3. ISO → **addRole** (`NDS_ACTION=addRole`) → **manager** → first boot `swarm init`.
4. On the toolkit: run `toolkit` (menu). Encrypt stubs, harvest tokens, enroll hosts from there. `toolkit-update` pulls a new tools VERSION.
5. **addRole** gateway / workers (join from sops). Enroll each machine from the toolkit menu.

Grant the ISO **write** access to this repo. Operator private keys stay in the toolkit bundle zip — never in git.
