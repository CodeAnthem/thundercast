# NDS — Nix Deploy System

[![NDS selftest](https://github.com/CodeAnthem/thundercast/actions/workflows/nds-selftest.yml/badge.svg)](https://github.com/CodeAnthem/thundercast/actions/workflows/nds-selftest.yml)
[![NDS shellcheck](https://github.com/CodeAnthem/thundercast/actions/workflows/nds-shellcheck.yml/badge.svg)](https://github.com/CodeAnthem/thundercast/actions/workflows/nds-shellcheck.yml)

Live-ISO / curl installer. Generic birth of NixOS machines (classic or flake).

## Layout

```
nds/
  start.sh                 curl entry (clone repo → nds/src/app/main.sh)
  src/app/                 framework: CLI, pipeline, confirm, finish
  src/recipe/              recipe contract
  src/wizard/              interactive fill, askers, git access
  src/realize/             birth from a sealed recipe
  src/utilities/           disk, nixos, nixcfg, git, flake, and the other tools
  src/actions/             classicInstall, installFlake, apply, remoteAction, test, uiSmoke
  dev/                     selftest and shellcheck
```

Fleet actions (`toolkit`, `addFleetHost`) live in `../fleet/nds-actions/` and are discovered with the builtins.

## Run

```bash
curl -sSL https://raw.githubusercontent.com/CodeAnthem/thundercast/main/nds/start.sh | bash
# or
bash nds/src/app/main.sh
bash nds/src/app/main.sh --unattended --action classicInstall
bash nds/src/app/main.sh apply /path/to/host.recipe
```

## Tests

```bash
bash nds/dev/selftest.sh
bash nds/dev/shellcheck.sh
```

Requires Bash 5.3+.
