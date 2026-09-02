# tcast — host CLI

[![tcast selftest](https://github.com/CodeAnthem/thundercast/actions/workflows/tcast-selftest.yml/badge.svg)](https://github.com/CodeAnthem/thundercast/actions/workflows/tcast-selftest.yml)
[![tcast shellcheck](https://github.com/CodeAnthem/thundercast/actions/workflows/tcast-shellcheck.yml/badge.svg)](https://github.com/CodeAnthem/thundercast/actions/workflows/tcast-shellcheck.yml)

NDS-free tools for any NixOS host. **Command:** `tcast` (not `tc` — iproute2 owns that).

## Layout

```
tcast/
  bin/ commands/ lib/ modules/tcast/ package.nix VERSION
  docs/TODO.md
  dev/
```

## Durable state

`/var/lib/tcast/` — `git.map`, conf.

## Tests

```bash
bash tcast/dev/selftest.sh
bash tcast/dev/shellcheck.sh
```

Flake: `packages.tcast` + `nixosModules.tcast`.
