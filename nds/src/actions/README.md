# NDS actions

An action is `setup.sh`. Discovery reads that file only.

```bash
# Description: one line, within the first 20 lines
action_groups()   { printf '%s\n' install disk; }
action_preview()  { ui_h "..."; ui_b "..."; }
action_defaults() { printf '%s\n' KEY=value; }   # optional, after seed
action_pins()     { printf '%s\n' INSTALL_KIND=classic; }  # optional, last, locked
action_recipe()   { local -n R=$1; }             # optional fill hook
```

`action_groups` and `action_preview` are required. `action_recipe` may write under the session dir and the leaf clone, and may set recipe keys. It does not prompt, push, partition, or call `nixos-install` / `nds_cook`.

Register hooks with `eventRegister` from `setup.sh` or a file it sources. The hook receives the recipe array name. Slots: `recipe.schema`, `recipe.done`, `cook.pre_disk`, `cook.post_disk`, `cook.pre_install`, `cook.post_install`, `cook.done`, `bundle.collect`. No other NDS events.

`apply` reloads the recipe's `INSTALL_ACTION` setup so those hooks run again on restore.

| Action | Groups | Pins | `action_recipe` |
|---|---|---|---|
| classicInstall | install region network access boot disk encryption platform | `INSTALL_KIND=classic` | none |
| installFlake | install flake git network access boot disk encryption | `INSTALL_KIND=flake` | none |
| apply | every group | none | none |
| remoteAction | install catalog | `INSTALL_KIND=flake` | clone the catalog, then fill the named action |
| toolkit | install toolkit flake git boot disk encryption platform | `INSTALL_KIND=flake`, `INSTALL_MODE=local` | operator keys, leaf, seed |
| addFleetHost | install flake git scaffold network boot disk encryption | `INSTALL_KIND=flake` | scaffold the host and set the leaf push |
| test, uiSmoke | hidden unless `NDS_TEST` | | |

Fleet actions live in `fleet/nds-actions/<name>/` and may keep helpers in `logic/`.
