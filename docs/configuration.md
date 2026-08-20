# NDS configuration reference

Every NDS setting maps to an environment variable: `NDS_<KEY>`.

Set variables before starting NDS, or paste the export lines printed at the end of configuration.

## Runtime flags (not stored in CONFIG_DATA)

| Variable | Description |
|----------|-------------|
| `NDS_AUTO_CONFIRM` | Umbrella — skip interactive menus and Y/n prompts (`true`) |
| `NDS_ACTION` | Action name — skip action picker (e.g. `installFlake`) |
| `NDS_ACTION_PREVIEW_SKIP` | Skip install preview screen (`true`) |
| `NDS_CAST_WARN_SKIP` | Skip the one-time remote-action fetch warning (`true`) |
| `NDS_SKIP_MENU` | Skip configuration category menu when validation passes (`true`) |
| `NDS_CONFIG_CONFIRM_SKIP` | Skip “continue to installation review” (`true`) |
| `NDS_INSTALL_CONFIRM_SKIP` | Skip local install confirmation (`true`) |
| `NDS_REMOTE_CONFIRM_SKIP` | Skip remote install confirmation (`true`) |
| `NDS_GIT_AUTH_SKIP` | Skip git SSH wizard **and fail** if access is missing (`true`). `NDS_AUTO_CONFIRM` does **not** skip git auth. |
| `NDS_DISK_FORMAT_CONFIRM_SKIP` | Skip destructive disk format confirmation (`true`) |
| `NDS_BACKUP_CONFIRM_SKIP` | Skip backup zip copy confirmation (`true`) |
| `NDS_REBOOT_SKIP` | Interactive only — skip the “Reboot now?” prompt (`true`) |
| `NDS_REBOOT_FORCE` | Unattended only — reboot after install (`true`). Unattended **never** reboots unless this is set (so you can copy the bundle). |
| `NDS_SCAFFOLD_OVERWRITE_SKIP` | Skip scaffold host-dir overwrite prompt (`true`) |
| `NDS_HARDWARE_OVERWRITE_SKIP` | Skip hardware file overwrite prompt (`true`) |
| `NDS_PREFLIGHT_WARN_SKIP` | Auto-continue past preflight warnings (`true`) |
| `NDS_PROMPTS_SKIP` | Skip generic Y/n prompts (`nds_ask_user_*`) (`true`) |
| `NDS_SCOPED_CONFIG_FILE` | Path to a file of `export NDS_*=` lines (optional `declare -gA` git maps). Sourced at startup. Needed for git maps: arrays cannot ride `curl \| bash` or `sudo`. |
| `NDS_GIT_IMPORT_KEY_PATH` | Path to a private SSH key to import before git auth (USB/scp) |
| `NDS_GIT_IMPORT_KEY` | Private SSH key **text** (PEM / OpenSSH). One key for all URLs. Not stored in CONFIG_DATA. Prefer `NDS_GIT_KEY_BODY` for per-repo. Unencrypted keys for headless (a passphrase prompt needs a TTY). |
| `NDS_DEPLOY_KEY_PATH` | Deprecated alias for `NDS_GIT_IMPORT_KEY_PATH` |
| `NDS_GIT_SSH_KEY_USE_QR` | Skip QR prompt on manual path — `true` or `false` |
| `NDS_GIT_SSH_KEY_DISPLAY` | Manual display mode: `qr` or `copy` |
| `NDS_GIT_SESSION_KEY_PATH` | Session private key path (default `/root/.ssh/git-<owner>-key`) |

## CLI flags

| Flag | Effect |
|------|--------|
| `--auto-confirm` | Sets `NDS_AUTO_CONFIRM` and all `NDS_*_SKIP` flags above. Does **not** reboot; set `NDS_REBOOT_FORCE=true` to reboot after unattended install. |
| `--skip-menu` | Sets `NDS_SKIP_MENU` |
| `--action NAME` | Sets `NDS_ACTION` (e.g. `--action installFlake`) |

---

## installFlake / remoteAction

| Key | Env | Export | Description |
|-----|-----|--------|-------------|
| `INSTALL_MODE` | `NDS_INSTALL_MODE` | when set | `local` (live ISO) or `remote` (nixos-anywhere) |
| `REMOTE_TARGET_IP` | `NDS_REMOTE_TARGET_IP` | changed | Target IP when `INSTALL_MODE=remote` |
| `FLAKE_REPO_URL` | `NDS_FLAKE_REPO_URL` | when set | Git SSH/HTTPS URL for remote flake |
| `FLAKE_LOCAL_PATH` | `NDS_FLAKE_LOCAL_PATH` | when set | Local path to flake on live ISO |
| `FLAKE_LOCATION` | `NDS_FLAKE_LOCATION` | never | Derived — use `FLAKE_REPO_URL` or `FLAKE_LOCAL_PATH` |
| `FLAKE_SOURCE` | `NDS_FLAKE_SOURCE` | never | Derived `remote` or `local` |
| `FLAKE_HOST` | `NDS_FLAKE_HOST` | when set | `nixosConfigurations` name |
| `FLAKE_INSTALL_PATH` | `NDS_FLAKE_INSTALL_PATH` | when set | Flake git root on target (default `/mnt/etc/nixos`) |
| `FLAKE_HOST_DIR` | `NDS_FLAKE_HOST_DIR` | when set | Host directory under flake (default `hosts/x86_64-linux`) |
| `FLAKE_HARDWARE_PLACEMENT` | `NDS_FLAKE_HARDWARE_PLACEMENT` | when set | `host-dir`, `flake-root`, or `skip` |
| `CAST_REPO_URL` | `NDS_CAST_REPO_URL` | when set | Remote-action git URL (remoteAction; default Thundercast) |
| `CAST_ACTION` | `NDS_CAST_ACTION` | when set | Remote action id (`.nds/actions/<id>.sh`) |
| `CAST_TOOLKIT_MODE` | `NDS_CAST_TOOLKIT_MODE` | when set | `new` or `restore` |
| `SOPS_AGE_REUSE` | `NDS_SOPS_AGE_REUSE` | when set | `generate` or `file` |
| `SOPS_AGE_KEY_FILE` | `NDS_SOPS_AGE_KEY_FILE` | when set | Existing machine age key path |

After install, per-repo deploy keys land under `/root/.ssh/nds_deploy_<owner>_<repo>` with  
`nds-git-ssh` + `nds-git.map` so stock `git+ssh://git@github.com/...` flake URLs keep working  
via `GIT_SSH_COMMAND`. Session / account keys stay on the live ISO; only `nds_deploy_*` keys  
are copied to the installed system. NDS also installs `/root/.nds/bin/nds-switch` and  
`/root/.nds/bin/nds-clean` (legacy `/root/bin`). Use `nds-switch --self-update` during NDS  
development to refresh scripts from ThunderCast without reinstalling. Install-time  
`facter.json` is unstaged and gitignored after the flake build so the checkout stays  
pullable. Structural `mounts.nix` + `boot.nix` are committed (or git-added at install) so  
flake eval always sees root/boot mounts and the bootloader device.

---

## disk

| Key | Env | Hardware | Description |
|-----|-----|----------|-------------|
| `DISK_TARGET` | `NDS_DISK_TARGET` | yes | Target block device (auto-detected) |
| `DISK_STRATEGY` | `NDS_DISK_STRATEGY` | yes | `nds`, `disko`, or `flake` |
| `DISK_FS_TYPE` | `NDS_DISK_FS_TYPE` | yes | Root filesystem type |
| `DISK_SWAP_SIZE_MIB` | `NDS_DISK_SWAP_SIZE_MIB` | yes | Swap size in MiB (`0` = none) |
| `DISK_DISKO_CONFIG` | `NDS_DISK_DISKO_CONFIG` | yes | Path to disko config when strategy is disko |

---

## boot

| Key | Env | Hardware | Description |
|-----|-----|----------|-------------|
| `BOOT_UEFI_MODE` | `NDS_BOOT_UEFI_MODE` | yes | `uefi` or `bios` (auto-detected) |
| `BOOT_LOADER` | `NDS_BOOT_LOADER` | yes | `grub`, `systemd-boot`, or `refind` |

---

## encryption

| Key | Env | Description |
|-----|-----|-------------|
| `ENCRYPTION` | `NDS_ENCRYPTION` | Enable LUKS2 (`true`/`false`) |
| `ENCRYPTION_PASSWORD` | `NDS_ENCRYPTION_PASSWORD` | Unlock with passphrase |
| `ENCRYPTION_PASSWORD_AUTO` | `NDS_ENCRYPTION_PASSWORD_AUTO` | Generate passphrase |
| `ENCRYPTION_PASSWORD_LENGTH` | `NDS_ENCRYPTION_PASSWORD_LENGTH` | Generated passphrase length |
| `ENCRYPTION_KEY` | `NDS_ENCRYPTION_KEY` | Unlock with keyfile |
| `ENCRYPTION_KEY_AUTO` | `NDS_ENCRYPTION_KEY_AUTO` | Generate keyfile |
| `ENCRYPTION_KEY_LENGTH` | `NDS_ENCRYPTION_KEY_LENGTH` | Keyfile size in bytes |
| `ENCRYPTION_KEY_BOOT_DEVICE` | `NDS_ENCRYPTION_KEY_BOOT_DEVICE` | Raw USB device for keyfile |
| `ENCRYPTION_KEY_BOOT_FILE` | `NDS_ENCRYPTION_KEY_BOOT_FILE` | File path on USB |
| `ENCRYPTION_REMOTE_UNLOCK` | `NDS_ENCRYPTION_REMOTE_UNLOCK` | SSH in initrd for remote unlock |
| `ENCRYPTION_REMOTE_SSH_KEY` | `NDS_ENCRYPTION_REMOTE_SSH_KEY` | Public key allowed in initrd |
| `ENCRYPTION_REMOTE_NETWORK` | `NDS_ENCRYPTION_REMOTE_NETWORK` | `dhcp` or static |
| `ENCRYPTION_REMOTE_PORT` | `NDS_ENCRYPTION_REMOTE_PORT` | Initrd SSH port (default `2222`) |
| `ENCRYPTION_REMOTE_HINT` | `NDS_ENCRYPTION_REMOTE_HINT` | Magenta console line with port + IP (`true` by default) |
| `ENCRYPTION_REMOTE_SHUTDOWN` | `NDS_ENCRYPTION_REMOTE_SHUTDOWN` | Seconds to wait at the LUKS prompt before power-off: `0` = off, else `30`–`3600` (`0` by default). Replaces `ENCRYPTION_REMOTE_HARDEN`. |

Set `export NDS_ENCRYPTION=false` (or any other `NDS_*` key) before start, or put the same lines in `NDS_SCOPED_CONFIG_FILE`.

---

## network

| Key | Env | Hardware | Description |
|-----|-----|----------|-------------|
| `NETWORK_HOSTNAME` | `NDS_NETWORK_HOSTNAME` | yes | System hostname |
| `NETWORK_METHOD` | `NDS_NETWORK_METHOD` | yes | `dhcp` or `static` |
| `NETWORK_IP` | `NDS_NETWORK_IP` | yes | Static IPv4 |
| `NETWORK_MASK` | `NDS_NETWORK_MASK` | yes | Subnet mask |
| `NETWORK_GATEWAY` | `NDS_NETWORK_GATEWAY` | yes | Default gateway |
| `NETWORK_DNS_PRIMARY` | `NDS_NETWORK_DNS_PRIMARY` | yes | Primary DNS |
| `NETWORK_DNS_SECONDARY` | `NDS_NETWORK_DNS_SECONDARY` | yes | Secondary DNS |

---

## access

| Key | Env | Description |
|-----|-----|-------------|
| `ACCESS_ADMIN_USER` | `NDS_ACCESS_ADMIN_USER` | Admin username |
| `ACCESS_ADMIN_PASSWORD_AUTO` | `NDS_ACCESS_ADMIN_PASSWORD_AUTO` | Generate admin password |
| `ACCESS_ADMIN_PASSWORD_LENGTH` | `NDS_ACCESS_ADMIN_PASSWORD_LENGTH` | Generated password length |
| `ACCESS_ADMIN_PASSWORD` | `NDS_ACCESS_ADMIN_PASSWORD` | Manual password |
| `ACCESS_ADMIN_SSH_KEY` | `NDS_ACCESS_ADMIN_SSH_KEY` | Admin SSH public key |
| `ACCESS_SUDO_PASSWORD_REQUIRED` | `NDS_ACCESS_SUDO_PASSWORD_REQUIRED` | Require password for sudo |
| `ACCESS_SSH_ENABLE` | `NDS_ACCESS_SSH_ENABLE` | Enable OpenSSH |
| `ACCESS_SSH_PORT` | `NDS_ACCESS_SSH_PORT` | SSH port |
| `ACCESS_SSH_PASSWORD_AUTH` | `NDS_ACCESS_SSH_PASSWORD_AUTH` | Allow password SSH login |

---

## region / quick / platform / security

See preset defaults in `src/app/settingsManager/data/builtin/`. Keys follow the same `NDS_<KEY>` pattern.

---

## Remote flake preset injection

After cloning a flake, NDS loads optional preset hooks from:

| Path | Purpose |
|------|---------|
| `.nds/preset.sh` | Single extra preset (preset id = filename without `.sh`) |
| `.nds/presets/*.sh` | Multiple presets |

Each file uses the same hook contract as builtins: `{id}_defaults`, `{id}_configure`, `{id}_validate`, `{id}_summary`, plus `NDS_PRESET_PRIORITY` and `NDS_PRESET_DISPLAY`.

Extra paths before the action runs (no flake clone needed):

| Env | Purpose |
|-----|---------|
| `NDS_PRESET_EXTRA_DIR` | Directory of `.sh` preset files |
| `NDS_PRESET_EXTRA_PATHS` | Colon-separated preset files or directories |

Actions may also implement `action_presets_paths()` to print extra paths (one per line).

See `src/tests/fixtures/nds-remote-preset.sh` for a minimal example.

## Headless installFlake example

```bash
export NDS_ACTION=installFlake
export NDS_FLAKE_REPO_URL="git@github.com:ORG/dp_cluster.git"
export NDS_FLAKE_HOST="worker-01"
export NDS_DISK_TARGET="/dev/nvme0n1"
export NDS_GIT_IMPORT_KEY_PATH="/tmp/nds-ssh-key"
# Flip individual SKIP flags to true, or use --auto-confirm for all:
export NDS_SKIP_MENU="false"
export NDS_INSTALL_CONFIRM_SKIP="false"
sudo -E bash src/app/main.sh --auto-confirm
```

### Recreate from the bundle

The install zip includes **`nds-restore.env`**: `# Settings` (exports + git URL maps), `# Runtime`, then live curl. Paste the whole file into a live ISO, or copy only the export blocks and run curl yourself. Do not `source` the file (curl would run).

Private git keys used during the install are copied to **`secrets/git/`**. Copy them to `/root/.ssh/` (`chmod 600`) before starting NDS. Restore `NDS_GIT_KEY_PATH` values point at `/root/.ssh/<filename>` (not the live-ISO path from the original run). Key **text** is never written into `nds-restore.env`.

Git URL maps cannot ride `sudo` or `curl | bash`. To load maps without pasting curl, copy the Settings and Runtime sections into a `.env` file and set `NDS_SCOPED_CONFIG_FILE`.

Per-repo git access (URL-keyed) — only arrays in the contract. A flake restore lists **every** private git input (root + flake.lock), not just the root repo:

```bash
declare -gA NDS_GIT_METHOD=(
  ['git@github.com:CodeAnthem/dp_cluster.git']='account'
  ['git@github.com:CodeAnthem/thundercast.git']='account'
  ['git@github.com:CodeAnthem/thundercore.git']='account'
)
declare -gA NDS_GIT_KEY_PATH=(
  ['git@github.com:CodeAnthem/dp_cluster.git']='/root/.ssh/git-codeanthem-key'
  ['git@github.com:CodeAnthem/thundercast.git']='/root/.ssh/git-codeanthem-key'
  ['git@github.com:CodeAnthem/thundercore.git']='/root/.ssh/git-codeanthem-key'
)
# Optional: paste key material per URL (never restore-exported). Use $'...' for newlines.
# declare -gA NDS_GIT_KEY_BODY=(
#   ['git@github.com:CodeAnthem/dp_cluster.git']=$'-----BEGIN OPENSSH PRIVATE KEY-----\n...\n-----END OPENSSH PRIVATE KEY-----'
# )
```

After interactive configuration, the **Configuration export** screen lists changed `export NDS_*=` lines. Private git auth has **no skip** — `NDS_AUTO_CONFIRM` still opens the GH wizard when keys are missing. Set `NDS_GIT_AUTH_SKIP=true` only when access is already proven (then missing access fails hard).

## Operator prepare kit

On your laptop (with `gh` authenticated):

```bash
./dev/operator/prepare-install-kit.sh worker-01
```

Copy `ssh_key` to the live ISO and set `NDS_GIT_IMPORT_KEY_PATH` as above.

## Git auth wizard (interactive)

installFlake runs an **early access gate** (URL → auth → host picker → target)
before the settings manager. Each private repository is its own conversation
(section title = `host/owner/repo`). Git auth is not skipped by `NDS_AUTO_CONFIRM`.

| Step | Options |
|------|---------|
| Have an existing private key? | yes / no (default **no**) |
| Yes | `paste` (hidden) / `path` |
| No (GitHub) | `gh` CLI / `generate` |
| No (other forges) | `generate` |
| Strategy (root repo) | `deploy-this` / `account-this` / `deploy-all` / `account-all` |

Missing flake.lock inputs repeat the same per-repo conversation (never a lumped
“missing repositories” prompt). `deploy-all` with a **new** key still auto-registers
same-owner deploy keys (gh or generate).

Per-URL maps (restore / unattended):

```bash
declare -gA NDS_GIT_EXISTING_KEY=(
  ['git@github.com:CodeAnthem/dp_cluster.git']='true'
  ['git@github.com:CodeAnthem/thundercast.git']='true'
)
declare -gA NDS_GIT_KEY_MODE=(
  ['git@github.com:CodeAnthem/dp_cluster.git']='paste'
  ['git@github.com:CodeAnthem/thundercast.git']='path'
)
```

`key_mode` is `paste` | `path` | `gh` | `generate`. If `paste`, even unattended
installs prompt to paste that repo’s private key (TTY). `path` uses
`NDS_GIT_KEY_PATH[url]` when the file exists.

`path` asks for a key file. `paste` reads the private key as hidden multiline input (like a password) until the `-----END … PRIVATE KEY-----` line. That TTY paste still works under `NDS_AUTO_CONFIRM` (git auth is not skipped). Without a terminal, set `NDS_GIT_KEY_BODY[url]` or `NDS_GIT_IMPORT_KEY`. Key text is never written to `nds-restore.env`.

QR codes load only on the **generate** register path (not gh or paste).

Non-GitHub hosts skip gh. QR codes are offered only on the generate path. The gh session is cleared after a successful install; on abort you may choose to clear it.
