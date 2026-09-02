# NDS — Nix Deploy System

[![NDS selftest](https://github.com/CodeAnthem/thundercast/actions/workflows/nds-selftest.yml/badge.svg)](https://github.com/CodeAnthem/thundercast/actions/workflows/nds-selftest.yml)
[![NDS shellcheck](https://github.com/CodeAnthem/thundercast/actions/workflows/nds-shellcheck.yml/badge.svg)](https://github.com/CodeAnthem/thundercast/actions/workflows/nds-shellcheck.yml)

Live-ISO / curl installer. Generic birth of NixOS machines (classic or flake).

## Layout

```
nds/
  start.sh       # curl entry (clone repo → nds/src/app/main.sh)
  src/           # app, install, wizard/git, utilities, ui, lib, tools, actions/
  src/actions/   # core only: classicInstall, installFlake, apply, remoteAction, …
  docs/TODO.md   # documentation backlog
  dev/           # selftest + shellcheck
```

Fleet birth wizards (`toolkit`, `addFleetHost`) live in `../fleet/nds-actions/` and are auto-discovered.

## Run

```bash
curl -sSL https://raw.githubusercontent.com/CodeAnthem/thundercast/main/nds/start.sh | bash
# or
bash nds/src/app/main.sh
```

## Tests

```bash
bash nds/dev/selftest.sh
bash nds/dev/shellcheck.sh
```

Requires Bash 5.3+.
