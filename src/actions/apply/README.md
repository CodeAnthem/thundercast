# apply

Part A only: install from a complete settings recipe. No composer wizard.

```bash
sudo bash src/app/main.sh apply /path/to/host.recipe
# same:
sudo bash src/app/main.sh --action apply --recipe /path/to/host.recipe
sudo bash src/scripts/tc-nds.sh apply /path/to/host.recipe
```

`NDS_RECIPE_FILE` is equivalent to `--recipe`.

## Recipe

Sectioned `tc-recipe v1` or `export NDS_*=` lines. Leaf files: `.nds/hosts/<host>.recipe`.

Registered secrets (`ACCESS_ADMIN_PASSWORD`, `ENCRYPTION_PASSPHRASE`, `TOOLKIT_AGE_KEY`, `TOOLKIT_SSH_KEY`) must be **file paths** (`*_FILE`). Values in the recipe are ignored.

Kind is inferred: flake keys (`FLAKE_HOST` / `FLAKE_REPO_URL` / `FLAKE_LOCAL_PATH`) → flake Part A; otherwise classic (local only).

## Validate first

Apply calls `nds_sm_load` then `nds_sm_validate` (same hooks as the menus). Incomplete recipes fail before disk wipe.

To **write** a recipe, run a composer (classicInstall / installFlake / addRole / toolkit) and save the export, or copy the leaf `.recipe` after a successful compose.
