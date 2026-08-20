# Install from flake

Installs `nixosConfigurations.<host>` from your flake. NDS handles disk prep, hardware facts, and staging — your flake owns system config.

## Disk strategies

| Strategy | Who partitions |
|----------|----------------|
| `nds` | NDS — simple GPT + optional LUKS |
| `disko` | NDS runs Disko (template or `DISKO_CONFIG`) |
| `flake` | Your flake — mount `/mnt` first |

## Hardware placement

| Mode | Where hardware-configuration.nix lives |
|------|--------------------------------------|
| `host-dir` | `<flake>/hosts/.../<host>/` (gitignored) |
| `etc-nixos` | `/etc/nixos` + `--override-input hardware` |
| `skip` | Flake handles hardware |

## Menu categories

installFlake exposes **Your flake**, **Boot**, **Disk**, **Encryption**, and **Platform**.
Boot uses the same **nixcfg** path as classicInstall: at install time NDS writes
`boot.nix` next to the host and ensures `configuration.nix` imports `./mounts.nix` and
`./boot.nix`. Scaffolded hosts get by-label `mounts.nix`; install may rewrite to by-uuid.

### Boot

| Field | Purpose |
|-------|---------|
| `BOOT_UEFI_MODE` | UEFI vs BIOS (auto-detected from live ISO firmware) |
| `BOOT_LOADER` | `grub` \| `systemd-boot` \| `refind` |

### Your flake

| Field | Purpose |
|-------|---------|
| `FLAKE_LOCATION` | Git URL or local path — source (`remote`/`local`) is auto-detected |
| `FLAKE_HOST` | `nixosConfigurations` name |
| `FLAKE_INSTALL_PATH` | Flake path on installed system |
| `FLAKE_HOST_DIR` | Host subtree (default `hosts/x86_64-linux`) |
| `FLAKE_HARDWARE_PLACEMENT` | `host-dir` \| `etc-nixos` \| `skip` |

Accepted flake locations: `git@host:owner/repo(.git)`, `ssh://…`, `https://…` (converted
to SSH), or a filesystem path (`/…`, `./…`, `~/…`). Remote URLs and paths are
auto-classified.

### Private repositories

When a remote flake isn't reachable anonymously, NDS detects it and offers SSH
deploy-key setup in-place:

- Generates an ed25519 key on the live system (if missing)
- Prints the public key and the provider's deploy-key URL
- Switches the clone URL to SSH (`git@host:owner/repo.git`)
- Expects git SSH access to every private repository in the flake closure
  (root flake plus locked inputs such as thundercast). NDS probes each repo via
  `git ls-remote` before partitioning; the system is built once during `nixos-install`.

For env-driven installs you can still set `NDS_FLAKE_REPO_URL` (git URL) or
`NDS_FLAKE_LOCAL_PATH` (path) directly; `FLAKE_SOURCE` is derived automatically.

### Disk (shared preset)

| Field | Purpose |
|-------|---------|
| `DISK_STRATEGY` | `nds` \| `disko` \| `flake` |
| `DISKO_CONFIG` | Optional path to disko `.nix` (when strategy is `disko`) |

## Example

```bash
export NDS_FLAKE_REPO_URL=git@github.com:you/your-leaf.git
export NDS_FLAKE_HOST=my-server
export NDS_DISK_STRATEGY=nds
export NDS_FLAKE_HARDWARE_PLACEMENT=host-dir
export NDS_DISK_TARGET=/dev/vda
export NDS_ENCRYPTION=false
sudo bash src/app/main.sh
```
