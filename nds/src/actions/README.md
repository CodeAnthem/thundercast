# NDS actions

An action is `setup.sh`. Discovery reads that file only. It must have a `# Description:` line in the first 20 lines, plus `action_groups` and `action_preview`. The other functions are optional.

Sourcing `setup.sh` runs whatever sits at the top level. Preview does that inside a subshell, then the parent sources the file again after accept.

NDS calls a hook when the function exists. The action does not register it.

| When | Call |
|---|---|
| Select, in a subshell | `action_preview` |
| Start of fill | `action_groups`, seed, recipe file, environment |
| After that | `action_defaults`, then `action_pins` |
| After pins | `hook_access`, `hook_ask`, `hook_material` |
| After seal and confirm | `hook_cook`, then `hook_bundle`, then the zip |

`hook_ask` uses `nds_ask_if_empty` and `nds_ask_groups_if_empty`. A choice already set is not asked. `hook_material` uses `nds_materialize`. A secret file that already exists is not created. `hook_cook` calls `nds_install_classic`, `nds_install_flake`, or `nds_leaf_push`. The action does not name session directories. Those helpers do.

A catalog action sets `_NDS_RELOAD_HOOKS=1` after it sources the inner `setup.sh`. NDS starts the hook cycle again, so the inner `hook_access` runs.

`test` defines none of these hooks. `uiSmoke` defines `hook_ask`. `--import` and `--restore` are flags. They load a file, take `INSTALL_ACTION` from it, and still show the preview.

## Declare

These print data. NDS writes it. They do not partition, install, or change the machine.

### `action_groups`

Required. Prints one schema group name per line.

NDS enables those groups. That is which questions exist. It does not set their values.

### `action_defaults`

Optional. Prints `KEY=value` lines.

NDS sets each key when it is still empty. The key stays editable. Runs after seed, so a default does not replace a seed or a detect value.

### `action_pins`

Optional. Prints `KEY=value` lines.

NDS sets each key and locks it. Prefer `nds_pin` from `hook_ask` for a value the action will not ask, such as toolkit's `INSTALL_MODE=local`.

## Execute

These run the action's own logic. NDS calls them. The argument is the recipe array name. A non-zero return aborts the run when `set -e` is on. Do not add `|| return 1` after each call.

### `action_preview`

Required. Draws the preview and waits for accept.

Runs at select, inside a subshell, before the parent sources the file. Skip with `action.preview`. Unattended skips it. Back returns to the menu unless `NDS_ACTION` is set.

### `hook_access`

Optional. Call `nds_access_read` or `nds_access_write` with the URL key. NDS walks git inputs. The action does not.

### `hook_ask`

Optional. Ask empty choices. Call `nds_ask_if_empty` and `nds_ask_groups_if_empty`.

### `hook_material`

Optional. Generate files the choices asked for. Call `nds_materialize`. Leaf and seed paths stay in an NDS helper the action calls by name.

### `hook_cook`

Optional. Call `nds_install_classic`, `nds_install_flake`, `nds_leaf_push`. NDS does not read a phase list from the action.

### `hook_bundle`

Optional. Runs after cook, before NDS packs the sealed file and the secret files.

`action_recipe` still runs only when none of `hook_access`, `hook_ask`, and `hook_material` exist. That is the path `uiSmoke` uses.

## Not an action function

| Name | Why it is rejected |
|---|---|
| `action_setup` | Retired |
| `action_config` | Retired |
| `action_presets` | Retired |
| `action_presets_paths` | Retired |
| `action_on_accept` | Retired |
| `action_extend_settings_manager` | Retired |

Helpers under `logic/` are the action's own code. NDS does not call them unless `setup.sh` calls them or registers them as a hook.

## Builtin and fleet

| Action | Hooks |
|---|---|
| classicInstall | ask, material, cook |
| installFlake | access (read), ask, material, cook |
| toolkit | access (read), ask (pins local), material, cook |
| addFleetHost | access (write), ask, material, cook |
| remoteAction | access (read catalog), ask, then the catalog action's hooks |
| test | none |
| uiSmoke | ask, when interactive |

Fleet actions live in `fleet/nds-actions/<name>/`.
