# Classic install (no flake)

First NixOS install without a flake. NDS generates `/etc/nixos/configuration.nix` +
`hardware-configuration.nix` and runs `nixos-install`. You own nothing beforehand —
NDS asks the menu and builds a complete, bootable system.

**Architecture:** this action is compose-only (`setup.sh` → settings menu →
`nds_realize_confirm` → `nds_realize_run`). Realize (partition, nixcfg, nixos-install,
verify) is the engine under `nds/src/realize/` (`plan_classic.sh`); the actual work is done
by `utilities/{disk,nixcfg,hwconfig,nixos}`.

## What you configure

Timezone, locales, keyboard, **network**, **admin user**, bootloader, **disk**, and
optional **LUKS2 encryption** (passphrase, USB keyfile, or both — plus initrd SSH
**remote unlock**).

## What NDS does

1. Partition the target disk (and set up LUKS2 if encryption is enabled)
2. Generate `configuration.nix` + `hardware-configuration.nix`
3. Run `nixos-install`
4. Build an install backup zip (with a personalized `QUICK_START.md`), then reboot

The backup zip lands in `/home/nixos/` and contains everything below, personalized to
the machine you just installed. Copy it off the box **before** rebooting.

---

## After install

### First login

- **Admin user:** the name you chose (default `admin`).
- **Admin password:** if you left auto-generate on, it's in the backup zip at
  `secrets/admin_password.txt`; otherwise it's the password you set during configuration.
- **SSH from your PC:**

```bash
ssh admin@<machine-ip>
```

- Password login is enabled by default — use the password above. If you configured an
  SSH key with password login off, use your key instead.
- **Console login** works with the same admin user + password.

Change the admin password after first login:

```bash
passwd
```

---

## Remote unlock (initrd SSH)

When you enable **encryption -> remote unlock**, NDS starts a tiny SSH server **in the
initrd** (early boot, before the disk is decrypted). You SSH in and enter the LUKS
passphrase remotely, so the machine boots without a physical keyboard.

Quick version:

- Login is **root**, **pubkey-only**, on **port 2222** (configurable; kept off the
  system's port 22 so host keys don't clash). Use a dedicated key (`~/.ssh/nixos-unlock`).
- Logging in drops you **straight into the passphrase prompt** (`command="systemctl default"`).
- NDS prints the **port and address** in **magenta** on the console at boot. With DHCP the
  initrd requests its lease by MAC, so it gets the **same** IP as the booted machine.
- The initrd host key is in the backup zip at `secrets/initrd_ssh_host_ed25519_key`.

```bash
ssh -p 2222 -i ~/.ssh/nixos-unlock -o IdentitiesOnly=yes root@<machine-ip>
```

**Full guide (key generation, connecting, recovery, quirks):**
[docs/remote-unlock.md](../../docs/remote-unlock.md)
