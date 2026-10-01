# NDS architecture

VERSION path: `nds/src/VERSION`. Bash 5.3+. No Python.

## Names

| Word | Means |
|------|--------|
| Recipe | Fill. The wizard or an action writes keys. Fill owns `_NDS_RECIPE`. |
| Cook | Birth. `nds_cook` loads a sealed file into its own `local -A R` and builds the machine. |
| Action | Fills a recipe. It does not partition and it does not call `nixos-install`. |
| Tool | One job, arguments in, no prompt, no recipe array. |
| Schema | The only key table. Type checks are value shape. Machine-state checks are preflight. |

`--import` loads a recipe and `--restore` unpacks a bundle. Both read `INSTALL_ACTION` and still show the preview. Birth is the action's `hook_cook`.

## Pipeline

discover → select → fill recipe → materialize → seal → confirm → `nds_cook <file>` → bundle → finish.

Events hook into that sequence. They are not the sequence. `prompt` lives in `wizard/` only. Unattended never enters `wizard/`.

Secrets are `*_FILE` paths. Cook never generates them. The recipe array is passed by name.

Runtime flags are exactly: `NDS_MODE`, `NDS_SKIP` / `NDS_SKIP_<NAME>`, `NDS_YES`, `NDS_REBOOT`, `NDS_ACTION`, `NDS_RECIPE_FILE`, `NDS_IMPORT`, `NDS_RESTORE_FILE`, `NDS_FLEET_ACTIONS_DIR`, `NDS_TEST`. Every other `NDS_<KEY>` is a schema key. `_NDS_TARGET_ROOT` is internal (default `/mnt`).

Target data goes through `TARGET_SEED_DIR` (local copy, remote `--extra-files`). Target code is a cook hook registered from that action's `setup.sh`. Prefer a seed file when the effect is a file.

## Cook phases

After load, validate, and preflight, cook runs `COOK_PHASES`: a space-separated subsequence of the catalog. An unknown id or a list out of catalog order is an error before any disk work. An empty list fires the hooks and installs nothing. The action writes the list in `action_plan`. Cook does not read the action name.

Catalog order, and the hook fired before each region:

1. `cook.pre_disk` — `leaf_push` `disk`
2. `cook.post_disk` — `write_classic` `hardware_nix` `copy_configs` `stage_flake` `hardware_facter` `write_generated_host` `host_structure` `stage_host_files` `prefetch` `eval`
3. `cook.pre_install` — `install_classic` `install_flake` `install_anywhere`
4. then `seed` `seed_git` `sops`
5. `cook.post_install` — `bootloader` `verify`
6. `cook.done`

`step_bootloader`: UEFI registers firmware; BIOS returns 0 because `nixos-install` wrote GRUB. `hardware_nix` and `hardware_facter` are separate phases. Hooks stay on those slots. They are not phases.
