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
hosts/x86_64-linux/<name>/   # you: configuration.nix + opts.nix; NDS: nds_generated.nix
.roles/<id>/                 # templates — see .roles/README.md
.toolkit/                    # shared ops state — see .toolkit/README.md
.nds/
  hooks/lib/                 # ISO functions only (no register)
  hooks/<action>/            # nds_hook_register for that action only
  hosts/                     # NDS recipes (.recipe)
```

## Bootstrap order

1. Copy this tree to a private GitHub repo and `nix flake lock`.
2. ISO → **toolkit** (`NDS_ACTION=toolkit`) → leave Restore off → this leaf URL (write access). Toolkit installs `hosts/…/control-toolkit/` (create that host in git first). Local install only. A second ops VM: copy the host folder, `NDS_FLAKE_HOST=<name>`, Restore on.
3. ISO → **addRole** (`NDS_ACTION=addRole`) → **manager** → first boot `swarm init`.
4. On the toolkit: run `toolkit` (menu). Encrypt stubs, harvest tokens, enroll hosts from there. `toolkit-update` pulls a new tools VERSION.
5. **addRole** gateway / workers (join from sops). Enroll each machine from the toolkit menu.

Grant the ISO **write** access to this repo. Operator private keys stay in the toolkit bundle zip — never in git.
