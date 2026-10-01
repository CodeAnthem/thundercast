# NDS — Nix Deploy System

[![NDS selftest](https://github.com/CodeAnthem/thundercast/actions/workflows/nds-selftest.yml/badge.svg)](https://github.com/CodeAnthem/thundercast/actions/workflows/nds-selftest.yml)
[![NDS shellcheck](https://github.com/CodeAnthem/thundercast/actions/workflows/nds-shellcheck.yml/badge.svg)](https://github.com/CodeAnthem/thundercast/actions/workflows/nds-shellcheck.yml)

Live-ISO / curl installer. Generic birth of NixOS machines (classic or flake).

## Layout

```
nds/
  start.sh                 curl entry (clone repo → nds/src/app/main.sh)
  src/app/                 entry: main, chrome
  src/app/pipeline/        sequence, confirm, finish
  src/app/actionSelect/    discover, check, and pick an action
  src/app/session/         mode, skip, dirs, logs, exit
  src/recipe/              recipe contract
  src/wizard/              interactive fill, askers, git access
  src/cook/                birth from a sealed recipe
  src/utilities/           disk, nixos, nixcfg, git, flake, and the other tools
  src/actions/             classicInstall, installFlake, remoteAction, test, uiSmoke
  dev/                     selftest and shellcheck
```

Fleet actions (`toolkit`, `addFleetHost`) live in `../fleet/nds-actions/` and are discovered with the builtins.

## Run

```bash
bash nds/src/app/main.sh --unattended --action classicInstall
bash nds/src/app/main.sh --yes
bash nds/src/app/main.sh --skip action.preview,recipe.summary
bash nds/src/app/main.sh --reboot
bash nds/src/app/main.sh --import /path/to/host.recipe
bash nds/src/app/main.sh --restore /path/nds_bundle.zip
```

## Tests

```bash
bash nds/dev/selftest.sh
bash nds/dev/shellcheck.sh
sudo bash nds/dev/looptest.sh
```

`looptest.sh` is opt-in. It needs passwordless sudo plus `losetup`, `sgdisk`, `cryptsetup`, `mkfs.ext4`, and `mkfs.vfat`, and it is not part of the self-test. On WSL, `sudo modprobe loop` may be required first.

Requires Bash 5.3+.
