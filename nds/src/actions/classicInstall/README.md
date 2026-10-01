# classicInstall

Install NixOS from a generated `configuration.nix`. No flake.

Groups: `install region network access boot disk encryption platform`. No pin. `action_plan` writes the classic phase list. No `action_recipe`.

Birth is `nds_cook`: partition (LUKS when encryption is on), hardware configuration, `nixos-install`, then the restore bundle.

```bash
bash nds/src/app/main.sh --unattended --action classicInstall
```

Secrets are `*_FILE` paths. Set `NDS_DISK_TARGET` to the disk.
