# src/install

NixOS install pipeline — disk prep, secrets, `nixos-install`, backup bundle.

Loaded after action extension + settings init via `nds_app_prepareAction` (`nds_import_tree`).

## Layout

```
install/
  lib/                 Argument-only (disk_part, partition, luks, urandom, access_secrets)
  disk/                Partition, Disko, encryption (logic + ui)
  flake/               Flake gate, hosts, scaffold, flake nixos-install
  classic/             Classic pipeline, hardware facts, boot, context
  nix/                 Store helpers, sops, classic nixos-install runner
  verify/              Preflight, confirm, logs, diagnostics
  nixcfg/              configuration.nix builders + blocks (classic and flake)
  templates/           Disko + flake scaffold templates
  tests/               Colocated suites
```

## Related modules

- `src/git/` — SSH, clone, closure (calls `tools/` for gh)
- `src/app/bundle/` — Post-install backup zip + hooks
- `src/lib/` — Generic helpers (host IP, key-text markers)
- `src/tools/` — Capability helpers (pkg, qr, gh, age, facter)
- `src/scripts/` — Target-machine CLIs (`nds-switch`, `nds-clean`, `nds-git-ssh`)
