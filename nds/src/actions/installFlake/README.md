# installFlake

Install NixOS from a local or remote flake.

Groups: `install flake git network access boot disk encryption`. Pin: `INSTALL_KIND=flake`. No `action_recipe`.

`FLAKE_SOURCE=local` uses `FLAKE_LOCAL_PATH`. `FLAKE_SOURCE=remote` uses `FLAKE_REPO_URL`. Unattended git access needs a prepared `GIT_KEYS_DIR`.

```bash
bash nds/src/app/main.sh --unattended --action installFlake
```
