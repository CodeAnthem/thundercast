<p align="center">
  <img src="docs/assets/banner.png" alt="ThunderCast" width="700">
</p>

# ThunderCast

[![Version](https://img.shields.io/badge/version-5.24.20-0267c1?style=flat-square)](https://github.com/CodeAnthem/thundercast)
[![NixOS](https://img.shields.io/badge/NixOS-Live%20ISO-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.org)
[![ShellCheck](https://github.com/CodeAnthem/thundercast/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/CodeAnthem/thundercast/actions/workflows/shellcheck.yml)
[![Self-test](https://github.com/CodeAnthem/thundercast/actions/workflows/selftest.yml/badge.svg)](https://github.com/CodeAnthem/thundercast/actions/workflows/selftest.yml)

**ThunderCast** is the installer and operator repo: **NDS** (live-ISO install) plus the **toolkit** menu used on an ops host after install.

NixOS modules live in [Thunderstorm](https://github.com/CodeAnthem/thunderstorm) (private). This repo does not ship secrets, host inventory, or a ThunderCore compose chain.

```
ThunderCore → Thunderstorm (modules) → your private leaf
ThunderCast  → ISO / NDS actions / toolkit scripts
```

---

# Nix Deploy System (NDS)

**NDS is the guided NixOS installer for the live ISO** — pick a path, answer the menu, and it handles disk prep, hardware facts, staging, and `nixos-install` in order.

**NDS can:**

- Install with **no flake** — generates `/etc/nixos/configuration.nix` (`classicInstall`)
- Install from **your flake** — clone, place hardware facts, `nixos-install --flake` (`installFlake`)
- Run a **remote action** — catalog repo `.nds/actions/` + your install flake (`remoteAction`)
- Partition with NDS layouts, **Disko**, or defer to your flake
- Optional **LUKS2 encryption**: passphrase, USB keyfile, or both — plus initrd SSH **remote unlock**
- Print a **saved `NDS_*` config** you can reuse on the next machine

**NDS does not:**

- Ship your system configuration or secrets
- Replace your flake as the source of truth
- Wrap your flake in another flake
- Commit `hardware-configuration.nix` to your repo (it stays gitignored on disk)

---

## Install paths

| Path | Action | You need |
|------|--------|----------|
| **A** — first install, no flake | `classicInstall` | Live ISO + `nixos` user (sudo) |
| **B** — existing flake | `installFlake` | `nixosConfigurations.<host>`, Git SSH for private repos |
| **C** — new host from a catalog action | `remoteAction` | Catalog with `.nds/actions/` (this repo) + your install flake ([API](src/actions/remoteAction/README.md)) |

---

## Quickstart

### 1. Boot the live ISO

Download the [NixOS minimal ISO](https://nixos.org/download/), boot the target machine or VM, log in as **`nixos`** (passwordless on the console).

### 2. Remote shell (optional)

Use the live console, or SSH from **Linux, macOS, Windows 10+ (OpenSSH), or WSL**:

```bash
passwd               # on the live system — set a password for nixos
ip -4 a              # note the IP
ssh nixos@<ip>       # from your PC
```

### 3. Run NDS

Read [TRUST.md](TRUST.md) before piping a remote script into `bash`.

**Option A — one-liner** (downloads `start.sh`, clones to `/tmp`, runs the menu):

```bash
curl -sSL https://raw.githubusercontent.com/CodeAnthem/thundercast/main/start.sh | bash
```

**Option B — clone and run** (inspect the repo first):

```bash
git clone https://github.com/CodeAnthem/thundercast.git /tmp/thundercast
cd /tmp/thundercast
sudo bash src/app/main.sh    # nixos user — NDS re-execs with sudo if needed
```

Fork or offline? Set `NDS_REPO_URL` before the one-liner, or clone your fork in option B. See [TRUST.md](TRUST.md).

### 4. Import a saved config (optional)

Skip re-entering the menu by **exporting `NDS_*` variables** before step 3:

- **From a previous install** — when you press **X** in the menu, NDS prints an `export NDS_…` block. Save it. Paste or `source` that file before running NDS again.
- The same export is included in the install backup zip, so you can recover it from there too.

Any `NDS_<FIELD>` overrides the matching menu field (same names as the backup export). Example for a flake install:

```bash
source ./my-install.env    # or paste exports directly into the shell
sudo bash src/app/main.sh
```

| Variable | Purpose |
|----------|---------|
| `NDS_<FIELD>` | Preset any menu field |
| `NDS_AUTO_CONFIRM=true` | Skip yes/no prompts |
| `NDS_REPO_URL` / `NDS_REPO_NAME` | Point `start.sh` at a fork or different clone path |
| `DEBUG=1` | Verbose logging |

### 5. Pick an action

| Action | When | Guide |
|--------|------|-------|
| **classicInstall** | First NixOS install, no flake yet | [classicInstall](src/actions/classicInstall/README.md) |
| **installFlake** | Generic `nixos-install --flake` | [installFlake](src/actions/installFlake/README.md) |
| **remoteAction** | Catalog `.nds/actions/` + install flake | [remoteAction](src/actions/remoteAction/README.md) |

Then: walk the menu (or rely on your `NDS_*` imports) → press **X** → optionally save the export block (or get it in the final zip) → confirm the destructive step → install → back up the install package → reboot manually.

Logs on the live system: `/tmp/nds_session.log` (session events). After install the bundle has `logs/nds.log` (session + steps + diagnostics) and `logs/nixosInstallation.log` (`nixos-install` / flake build output only).

### 6. Back up install package

After install, NDS creates a zip in `/home/nixos/` (owned by the `nixos` user so `scp`/`ssh` work). It includes a personalized **`QUICK_START.md`**, `nds-restore.env`, generated configs, install logs, and unlock material when encryption was enabled (LUKS passphrase, keyfile, and/or initrd SSH host key).

If you enabled a **USB key**, the finish screen tells you exactly how to copy `secrets/luks_key.bin` onto a USB stick (raw `dd` to the device, or a file on a mounted USB) before rebooting — the key is never written to the target disk, so you must stage it on the USB yourself.

The bundle always has the **fixed name `nds_bundle.zip`** on the host (so commands never have to guess a timestamp), and the copy command renames it to a descriptive, timestamped file on your machine. NDS prints these with your machine's IP — paste one from a **second terminal** on your PC:

```bash
# Example — use the exact IP NDS shows on screen
scp nixos@192.168.1.50:/home/nixos/nds_bundle.zip ./nds_install_backup_20260629_225213_myhost.zip

ssh nixos@192.168.1.50 "cat /home/nixos/nds_bundle.zip" > nds_install_backup_20260629_225213_myhost.zip
```

NDS does not reboot automatically when encryption is enabled — reboot only after the package is safe offline.

---

## After install

Every install produces a backup zip in `/home/nixos/` with a personalized
**`QUICK_START.md`** at its root — first login, passwords, encryption/USB staging, and
remote unlock, all filled in for the machine you just built. Copy the zip off the box
before rebooting, then follow that file.

Post-install details live in each action's guide:

- **classicInstall** — [first login & remote unlock](src/actions/classicInstall/README.md#after-install)
- **installFlake** — your flake owns users, services and unlocking; see [installFlake](src/actions/installFlake/README.md)
- **remoteAction** — see [remoteAction](src/actions/remoteAction/README.md)

Topic guides live in [`docs/`](docs/) (e.g. [remote unlock](docs/remote-unlock.md)).

---

## Toolkit (ops host)

On a dedicated ops machine, NDS action **toolkit** seeds [`toolkitScripts/`](toolkitScripts/). Daily work is the `toolkit` menu (sops, nodes, git). `toolkit-update` refreshes those scripts from this repo; it does **not** ride `nixos-rebuild` / comin.

NixOS module: `nixosModules.toolkit` (enable from a leaf that already uses ThunderCore `my.lib`).

Copy [`exampleRepo/`](exampleRepo/) to a **private** git remote for a cluster leaf skeleton. Point NDS `FLAKE_REPO_URL` at that remote. `CAST_REPO_URL` defaults to this repository (actions).

Do not commit age private keys, SSH private keys, or unencrypted `secrets/`. Banner: [`docs/assets/`](docs/assets/).

---

## What happens under the hood

**Classic install (no flake):**

```
Live ISO → menu → disk prep → configuration.nix + hardware-configuration.nix → nixos-install
```

**Flake install:**

```
Live ISO → menu → disk prep (or skip if flake owns disko)
         → nixos-generate-config → stage flake → hardware in host dir
         → nixos-install --flake <path>#<host>
```

NDS clones your flake **directly** — no wrapper flake. Install-time files (`hardware-configuration.nix`, optional `machine.nix` for LUKS) are gitignored on disk.

---

## For flake maintainers

Link here from your leaf README for live-ISO installs. Copy `exampleRepo/` to a private remote, input **Thunderstorm** for modules and **ThunderCast** for NDS/toolkit, then pick **remoteAction** (or **installFlake** for an existing named host).

---

## Develop

```bash
bash dev/shellcheck.sh              # lint (installs ShellCheck to ~/.cache if needed)
bash dev/selftest.sh                # read-only self-tests
DEBUG=1 sudo bash src/app/main.sh
NDS_TEST=true sudo bash src/app/main.sh   # self-test action only
```
