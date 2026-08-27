# toolkitScripts changelog

Versions here are **tools only** (this tree). NixOS/comin is a separate channel.

## 0.4.0 — 2026-08-28

- Cluster state lives under `.toolkit/` (operator pubs, `machines/<host>/`, `sops/secrets.map`)
- `.sops.yaml` is compiled from that tree; scopes are not a separate cryptic KEY=value pile
- NDS ISO hooks must not own this folder


## 0.3.1 — 2026-08-20

- TTY idle: discard keystrokes except Ctrl+C until a prompt is active

## 0.3.0 — 2026-08-20

- `tc-sops` / `toolkit sops` — health, init, put, apply, encrypt (same ops as the menu)
- Prefer `tc-git-ssh` for leaf git when it is on PATH

## 0.2.4 — 2026-08-20

- Leaf stays at `/var/lib/nds-toolkit/leaf` (not `/etc/nixos` or comin)
- On start: fetch origin, fast-forward when clean
- If local edits overlap incoming files: offer reset, or keep editing and Apply & push
- Status lists the three git checkouts (nds-switch, comin, toolkit)

## 0.2.3 — 2026-08-20

- Fast-forward the leaf clone on start (it had stayed at the NDS install commit)
- Operator menus stay gated until Init writes `initialized_at` (a pubkey file is not enough)
- Status shows leaf revision / how far behind origin
- Decrypt health says when the key is not a recipient (stale ciphertext)

## 0.2.2 — 2026-08-20

- Empty sops tree is valid (no stub ciphertexts); health does not fail on zero files
- Secrets / scopes / apply / rotate stay hidden until this console's operator key is registered
- Scripted `TCAST_UI_KEYS` consume in the parent shell (not `$(read)`), so they cannot loop a menu
- Exhausted scripted keys never fall through to `/dev/tty`
- OpenSSH `PermitRootLogin` / `PasswordAuthentication` from opts use `mkForce`

## 0.2.1 — 2026-08-19

- Seed `TCAST_LEAF_DIR` from `/etc/nixos` when `TCAST_LEAF_REPO` is not set yet (still a separate clone)

## 0.2.0 — 2026-08-19

- Main menu: Status, Nodes, Sops, Update (single-key, NDS-style)
- Leaf git is `TCAST_LEAF_DIR` (not `/etc/nixos`)
- Public register under `.nds/toolkit-register/` (pubs + timestamps only)
- Sops: add/change/remove secrets, scopes, operator init/rotate, apply & push
- Nodes: inventory, add host from role; install still NDS-on-target
- Dropped Swarm harvest-tokens / worker-manager enroll flags
- Git push refuses private keys and unencrypted `secrets/`

## 0.1.1 — 2026-08-19

- Menu lines say what each item is for; `h` prints the usual order
- `sops-init` / harvest encrypt the real `secrets/…` path so `.sops.yaml` matches
- `toolkit-update` retargets origin away from the live-ISO temp clone
- Status shows tools origin and leaf `git status`

## 0.1.0 — 2026-08-19

- Menu-first `toolkit` console on the ops VM
- `toolkit-update` compares VERSION, shows changelog, prompts before applying
- Status, sops-init, enroll-host, updatekeys, harvest-tokens
