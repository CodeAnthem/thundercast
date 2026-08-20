# Testing ThunderCast

Two layers. **Automated** tests never partition a disk. **Live ISO / VM** cases are the ship gate for install paths.

Automated suites: `src/tests/README.md`. Configuration flags: [configuration.md](configuration.md).

---

## Automated (CI / laptop)

Run from a ThunderCast checkout. No root, no VM.

```bash
bash dev/selftest.sh             # NDS suites (settings sessions, actions, git, apply, …)
bash dev/shellcheck.sh           # every shipped .sh including src/scripts/tc-*.sh
bash toolkitScripts/tests/run.sh # toolkit + tc-sops — needs age-keygen and sops on PATH
```

`bash src/tests/run.sh` is the same NDS suite as `dev/selftest.sh`.

On the live ISO, `export NDS_TEST=true` then the `curl | bash` line below, and pick **test** (same suite) or **uiSmoke** (prompt walk, no install).

CI on `main`: ShellCheck + selftest. Toolkit tests are local until `age`/`sops` are in the workflow image.

---

## Live ISO / VM

You need a NixOS **minimal** ISO, a disposable VM (or bare metal), and — for flake paths — a **private leaf** with write Git access. ThunderCast itself is not an install flake.

Firmware: match the VM to what NDS detects (`BOOT_UEFI_MODE`). BIOS + GPT with a FAT `/boot` that is **not** an ESP will fail EFI `grub-install`. Check after boot: `[ -d /sys/firmware/efi ] && echo uefi || echo bios`.

Prefer a **fresh disk** per case that installs. Abort cases (V3, V6, V8) must not leave a new origin commit.

### Start NDS (`start.sh`)

Same one-liner every time. [`start.sh`](../start.sh) still exists: it clones to `/tmp/thundercast` on the first run, then `git fetch` + `reset --hard origin/main` on later runs. You do **not** `git clone` again when Cast has a new version.

Read [TRUST.md](../TRUST.md) before piping into bash.

```bash
curl -sSL https://raw.githubusercontent.com/CodeAnthem/thundercast/main/start.sh | bash
```

Flags after `--` go to NDS (`--action`, `--recipe`, `apply FILE`, `--auto-confirm`):

```bash
curl -sSL https://raw.githubusercontent.com/CodeAnthem/thundercast/main/start.sh | bash -s -- --action addRole
```

Env vars (`NDS_ACTION`, `NDS_FLAKE_REPO_URL`, `NDS_TEST`, …) are picked up the same way — export them, then curl. Fork: `NDS_REPO_URL` + curl that fork’s `start.sh`. Pin a branch: `| bash -s -- --branch:name`. Fetch without running: `| bash -s -- --no-exec`.

---

### V1 — classicInstall, local, no LUKS

| | |
|--|--|
| **Do** | Action `classicInstall`. DHCP, generated admin password, `DISK_STRATEGY=nds`, `ENCRYPTION=false`. Confirm wipe. Copy `nds_bundle.zip` off the box. Reboot. |
| **Pass** | Boots. Login as the admin user. SSH if you enabled it. Bundle has `QUICK_START.md` + `nds-restore.env`. |
| **Fail** | Installer returns before `nixos-install`, or no login after reboot. |

---

### V2 — installFlake, local, existing host

Use a host that already exists in the leaf (`nixosConfigurations.<name>`), with committed `mounts.nix` + `boot.nix`.

| | |
|--|--|
| **Do** | `NDS_ACTION=installFlake` (or pick it). Private flake URL → git wizard → pick host → **local** disk → menu → confirm. Reboot. |
| **Pass** | `findmnt /boot` is mounted. `tc-status` prints host + flake rev. `tc-switch` (or `nds-switch`) rebuilds without a GRUB/ESP error. `GIT_SSH_COMMAND` / `tc-git-ssh` can `git ls-remote` private inputs. |
| **Fail** | `/boot` missing after reboot, rebuild wants EFI on a BIOS disk, or private git fails on the installed system. |

Headless sketch (git auth still runs unless access is already proven):

```bash
export NDS_ACTION=installFlake
export NDS_FLAKE_REPO_URL="git@github.com:ORG/your-leaf.git"
export NDS_FLAKE_HOST="worker-lab"
export NDS_INSTALL_MODE=local
export NDS_DISK_TARGET=/dev/vda
export NDS_GIT_IMPORT_KEY_PATH=/tmp/nds-ssh-key
curl -sSL https://raw.githubusercontent.com/CodeAnthem/thundercast/main/start.sh | bash -s -- --auto-confirm
```

---

### V3 — addRole abort at disk confirm (no origin commit)

Note the leaf’s `origin/main` SHA **before** this run.

| | |
|--|--|
| **Do** | `NDS_ACTION=addRole`. Write access to the leaf. Pick a `.roles/` template and a **new** hostname. Walk the menu. At the **disk wipe** confirm, abort (`n` / Ctrl-C). |
| **Pass** | Origin SHA unchanged. No new `hosts/…/<name>/` on the remote. No `nixos-install`. |
| **Fail** | Host files were pushed before you confirmed wipe. |

---

### V4 — addRole full install

| | |
|--|--|
| **Do** | Same as V3, but confirm wipe. Wait for Part A. Copy the bundle. Reboot. |
| **Pass** | Remote has `hosts/<system>/<host>/` plus `.nds/hosts/<host>.recipe` (and legacy `.env`). Machine boots. Recipe has **paths** (`*_FILE`), not passphrase/password values. |
| **Fail** | Scaffold without install, or secrets in the committed recipe. |

---

### V5 — toolkit, local, mode `new`

The toolkit **host folder must already exist** in the leaf (example: `hosts/x86_64-linux/control-toolkit/`). Toolkit does not scaffold from `.roles/`.

| | |
|--|--|
| **Do** | `NDS_ACTION=toolkit`, `CAST_TOOLKIT_MODE=new`, **local** disk. Confirm wipe. After install, copy the bundle (private age + SSH keys live there). Reboot. |
| **Pass** | Git has **public** keys only (`.nds/operator.age.pub`, `.nds/toolkit.ssh.pub`). Private keys are in the zip / on `/mnt` (then the installed disk), not in git. `toolkit` menu starts. `tc-sops health` runs. `toolkit-update` is a tools fetch, not `nixos-rebuild`. |
| **Fail** | Private key committed, `toolkit` missing after boot, or install used `INSTALL_MODE=remote`. |

---

### V6 — toolkit refuses remote

| | |
|--|--|
| **Do** | `NDS_ACTION=toolkit` with `NDS_INSTALL_MODE=remote` (or pick remote in the menu). |
| **Pass** | Hard error: toolkit is local-only. No clone/push required after the refuse. |
| **Fail** | nixos-anywhere starts, or install continues without copying operator keys. |

---

### V7 — apply from a recipe (no wizard)

Take a `.recipe` from V2/V4 (or export after a menu **X**). Point `*_FILE` at files that exist on the ISO.

| | |
|--|--|
| **Do** | Wipe or use a new disk. `curl …/start.sh \| bash -s -- apply /path/to/host.recipe` (or `--action apply --recipe FILE`). |
| **Pass** | No settings menu. Part A installs. Same boot checks as V2 if it was a flake recipe. |
| **Fail** | Wizard opens, or apply ignores `FLAKE_*` and does a classic install by mistake. |

---

### V8 — ThunderCast catalog is empty

| | |
|--|--|
| **Do** | Interactive: pick **remoteAction**, leave catalog URL at ThunderCast. Unattended: `NDS_ACTION=remoteAction` without `NDS_CAST_ACTION`. |
| **Pass** | Fail closed. Message to use `NDS_ACTION=addRole` / `NDS_ACTION=toolkit`. Does **not** source `.nds/actions/addRole.sh` or `toolkit.sh`. |
| **Fail** | Defaults to addRole, or sources the stub and exits 14 after a fake “success” path. |

Compat (not preferred): `NDS_ACTION=remoteAction` + `NDS_CAST_ACTION=toolkit` must redirect to the **built-in** toolkit action, not the stub.

---

### V9 — `tc-git-ssh init` without NDS

On any NixOS/Linux box (GUI install included). No live ISO required.

```bash
# from this repo, or a copy of src/scripts/tc-git-ssh.sh on PATH
./src/scripts/tc-git-ssh.sh init owner/repo /absolute/path/to/ed25519
export GIT_SSH_COMMAND="$(pwd)/src/scripts/tc-git-ssh.sh"
git ls-remote git@github.com:owner/repo.git
```

| **Pass** | Writes `~/.ssh/tc-git.map`. `ls-remote` works with that key. |
| **Fail** | Requires a previous NDS install, or looks only at `nds-git.map`. |

---

### V10 — installFlake remote (optional)

Needs a **second** machine reachable with SSH (another VM is enough). Not toolkit.

| | |
|--|--|
| **Do** | `installFlake`, `INSTALL_MODE=remote`, target IP. Confirm remote wipe. |
| **Pass** | Target installs via nixos-anywhere and boots. ISO `/mnt` is unused for the target. |
| **Fail** | Keys or helpers expected on the ISO `/mnt` (wrong machine). |

---

### V11 — classicInstall + LUKS (optional)

Same as V1 with `ENCRYPTION=true` (passphrase and/or USB keyfile). If remote unlock: follow [remote-unlock.md](remote-unlock.md). Copy the bundle **before** reboot; USB keyfile is never written to the target disk.

---

## Suggested order

1. Automated three commands (green).
2. **V3** (abort) before any addRole that pushes.
3. **V2** (`/boot` + `tc-switch`) — highest value flake regression.
4. **V5** toolkit local, then **V6** refuse remote.
5. **V8** empty catalog, **V7** apply, **V9** git-ssh init.
6. **V1** / **V4** / **V10** / **V11** when you have spare disks.

---

## Out of scope (honest cuts)

| Path | Status |
|------|--------|
| `classicInstall` + `INSTALL_MODE=remote` | Not implemented |
| `toolkit` + nixos-anywhere | Refused on purpose until keys can land on the target |
| NDS wizard using multiple settings sessions | API exists (`nds_sm_create` / `nds_sm_use`); ISO flow uses the default store |
| Dropping legacy `.env` | Dual-write remains; **load** prefers `.recipe` |

`sid=$(nds_sm_create …)` runs in a subshell — the parent must `nds_sm_use "$sid"` (covered by `settings_sm` selftest).
