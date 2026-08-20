# exampleRepo — copy this to your private leaf

Thunderstorm (modules) / ThunderCast (NDS)’s **remoteAction** clones **your** private git remote, not this folder in-tree. Copy `exampleRepo/` to a new private repository **before** the first toolkit ISO. Point NDS `CAST_REPO_URL` at Thunderstorm (modules) / ThunderCast (NDS) (default) and `FLAKE_REPO_URL` at that private remote.

Do **not** install thundercast itself as the flake (no real `nixosConfigurations` here).

## Layout

```
flake.nix
setup/
hosts/x86_64-linux/          # per-machine; add the toolkit host here before the toolkit action
  control-toolkit/           # existing ops VM — toolkit action installs this (no role template)
.roles/                      # addRole only (manager, worker, gateway, …)
  manager/
  worker/
  gateway/
.nds/
  hosts/                     # NDS writes <hostname>.env + .inventory
  hooks/                     # optional
```

## Bootstrap order

1. Copy this tree to a private GitHub repo and `nix flake lock`.
2. ISO → **remoteAction** → Thunderstorm (modules) / ThunderCast (NDS) → action **toolkit** → **new** → this leaf URL (write access). Toolkit installs `hosts/…/control-toolkit/` (create that host in git first).
3. ISO → **addRole** → **manager** → first boot `swarm init`.
4. On the toolkit: run `toolkit` (menu). Encrypt stubs, harvest tokens, enroll hosts from there. `toolkit-update` pulls a new tools VERSION.
5. **addRole** gateway / workers (join from sops). Enroll each machine from the toolkit menu.

Grant the ISO **write** access to this repo. Operator private keys stay in the toolkit bundle zip — never in git.
