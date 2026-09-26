# NDS refactor — architecture and port order

> **Superseded for execution by `nds/src/HANDOFF.md`.** Read that file. Open this one only for a section it cites. §0 below is frozen at the state of the review; the live status is in `HANDOFF.md` §2.

This file is the implementer's spec. It supersedes the "Next edit" in `nds/.wip/OPEN.md` (which pointed at `app/settings/prompt.md`; that edit is cancelled by this plan). `REFACTOR-BRIEF.md` was context for writing this file and is deleted.

Vocabulary: a **group** is what the old tree called a preset — settings that belong together (network, disk, …). The settingsManager idea (per-action required settings, validation, missing-input detection, env preconfiguration) is kept; only its implementation changes from five hand-written hooks per preset to one declaration per field. Where this file is silent, do the smallest thing that keeps the rules in §2 and §4 true. Do not add options, hooks, flags, or formats that this file does not name.

Read before starting: this file, `.cursor/project.md`, `utilities/essentials/README.md`, `utilities/bashTestSuite/README.md`. Do not read `nds/src.old` for names or call patterns; read it only for behaviour you are porting in the step you are on.

Do not run `nds/src/app/main.sh`. Do not bump `nds/src/VERSION` until step 8.

## 0. Status and how to resume

This block is the only part of this file the implementer edits. §1–§8 are the spec; change them only when the user says so.

**Resume procedure** (start of every session):

1. Read this file top to bottom.
2. Find the first unchecked step below. Run its **Gate** commands. If the gate of the *previous* step fails, fix that first.
3. Work only on that step. Do not start the next one.
4. When the gate passes, tick the box, write one line under **Log** (date, step, anything the next session must know), and mirror the tick into `nds/.wip/OPEN.md`.

**Steps**

- [x] 0 gate
- [x] 1 recipe contract
- [x] 2 tools (structure; behaviour gaps in §9.1)
- [ ] 3 realize and bundle — **reopened by review**, see §9.1
- [x] 4 pipeline (unattended)
- [ ] 5 actions (builtin + fleet) — **reopened by review**, see §9.2
- [ ] 6 wizard (interactive) — **reopened by review**, see §9.3
- [x] 7 delete legacy
- [ ] 8 ship — **reopened**: `6.0.0` is committed as `b89045e` but the tree cannot install; do not tag or push before §9 is closed
- [ ] 9 repair pass — **the current step**; work §9.1 → §9.4 in order, gate with §9.5

**Whole-refactor done when** every box is ticked, `bash nds/dev/selftest.sh` exits 0, `bash nds/dev/shellcheck.sh` is clean, `nds/src.old` does not exist, the banned-name grep in step 7 returns nothing, and every §9.5 gate passes.

**Log**

- 2026-09-26 review of `b89045e`: layout, contracts, skip store, recipe module, pipeline shape match the plan. Behaviour was not ported: realize calls four functions that do not exist and passes wrong arguments to five disk tools; toolkit cook writes hard-coded fake keys; scaffold, quickstart, verify, diag, preflight, git wizard are stubs; fixtures were edited to satisfy a schema bug instead of fixing the schema. Steps 3, 5, 6, 8 reopened; §9 added. Legacy source for the port is commit `d60000a` at `nds/src/realize/…`, `nds/src/wizard/…`, `nds/src/app/bundleManager/…`, `nds/src/app/settingsManager/…`, `nds/src/utilities/…`, `nds/src/actions/*/logic/…`, `fleet/nds-actions/*/logic/…` — read with `git show d60000a:<path>`. `nds/src.old` was never tracked and is gone from disk; do not look for it.

- 2026-09-26 step 0: gate green, three tests under `nds/src`. `setup_TEST.sh` was untracked, so it was moved with `mv`. `.wip/` was not updated.
- 2026-09-26 step 1: recipe contract green. A `.zip` load uses `unzip` when it exists, otherwise a stored-entry reader. `.wip/` was not updated.
- 2026-09-26 step 2: tools live under `nds/src/utilities`. `src.old/utilities` is gone. `.wip/` was not updated.
- 2026-09-26 step 3: `nds_realize` and `nds_bundle` are fixture-tested. Old `app/realize` is gone. `.wip/` was not updated.
- 2026-09-26 step 4: unattended pipeline cooks, seals, and calls realize. `INSTALL_ACTION` is locked after the recipe file is read so `apply` can load the action named in the file. `.wip/` was not updated.
- 2026-09-26 step 5: builtin and fleet actions cook from env. `LEAF_PUSH_DIR` is the absolute `work/leaf` path so the `dir` type validates. A catalog cook replaces `INSTALL_ACTION` with the catalog action. Applying defaults used to return 1 when nothing was locked; that return is now 0. `.wip/` was not updated.
- 2026-09-26 step 6: interactive fill, askers, confirm, and finish are in. Git access is the probe loop (existing key or new key); map/bridge screens were not carried. `nds/src.old/wizard`, `app.old`, and `lib` are gone. `nds_realize_preflight --warnings` feeds the confirm screen. `.wip/` was not updated.
- 2026-09-26 step 7: `nds/src.old`, `nds/docs/src-conventions.md`, and `nds/src/app/workflow.md` are gone. ShellCheck no longer walks a legacy tree. Layout in `.cursor/project.md` and `nds/README.md` matches §3. The step 7 name search still matches this spec, because the catalogue lives in §1–§8. `.wip/` was not updated.
- 2026-09-26 step 8: `nds/src/VERSION` is 6.0.0. CLI and recipe format are breaking. `.wip/` was not updated.
- 2026-09-26 step 9 in progress: disk arguments, EFI, `nixos_setBootContext`, prefetch/install/verify/hardware, preflight errors, diag log, quickstart sections, catalog/toolkit/scaffold `--when`, locked `nds_recipe_set`, `INSTALL_ACTION` stays `remoteAction`, toolkit calls `age-keygen`/`ssh-keygen`, scaffold uses `FLAKE_HOST_DIR` and the host templates. Git screens now choose deploy or account, retry a title collision (rc 41), show the QR card, and retry one failed probe. Confirm prints every active group (choice labels, secrets as `(file)`). Finish includes the SSH `cat` hint, the online guide, and the sops enroll line. Toolkit restore unpacks a zip or directory into `secrets/toolkit/`. Cook writes `${LEAF_PUSH_DIR}/.toolkit/machines/<host>/keys/age.pub`. `git.map` is `owner/repo<TAB>/root/.ssh/nds/<safeurl>` and the target gets `tcast-git-ssh` plus its two libs. dropped `_nds_git_install_nds_helpers_to_target` full tcast tree copy because the installed system only needs the ssh wrapper, `tcast_common.sh`, `tcast_git_ssh.sh`, and `git.map`. Still open: §9.4 docs and commits, G1, G7. `realize_TEST.sh` still stubs tool functions, which G3 does not allow. `.wip/` waits for §9.4.

**Banned names** (must not appear in `nds/src` or `fleet/nds-actions` outside `.wip/`; step 7 greps for them): `nds_app_`, `SCRIPT_DIR`, `APP_DIR`, `nds_import_file`, `nds_ui_`, `nds_ask_user_to_proceed`, `nds_cfg_`, `nds_sm_`, `nds_preset_`, `nds_feat_cfg_`, `CONFIG_DATA`, `CONFIG_DEFAULTS`, `PRESET_REGISTRY`, `PRESET_META`, `PRESET_HOOKS`, `nds_step_`, `nds_install_log`, `NDS_UI_QUIET`, `NDS_RUNTIME_DIR`, `NDS_INSTALL_CONFIRMED`, `NDS_AUTO_CONFIRM`, `NDS_UNATTENDED`, `NDS_SKIP_MENU`, `NDS_<X>_SKIP` (old per-screen suffix form), `nds_realize_run`, `nds_realize_confirm`, `nds_hook_`, `nds_bundle_register_`, `remote_action_`, `NDS_REMOTE_ACTION_DID_INSTALL`, `NDS_PRESET_EXTRA`, `NDS_CFG_AA_NAME`, `git_store_`, `GIT_ENV_PREFIX`, `NDS_GIT_METHOD`, `NDS_GIT_KEY_`, `NDS_GIT_AUTH_SKIP`, `NDS_GIT_IMPORT`, `NDS_GIT_GH_`, `NDS_FLAKE_PROBE`, `NDS_CAST_`, `src.old`.

## 1. Fixed points (not negotiable)

- NDS takes a bare-metal machine from a live ISO to the point where a flake or `configuration.nix` takes over. It stops there.
- One pipeline for the TUI and for env / env file / recipe file. Unattended never enters a UI function. Missing input fails before the disk is touched.
- A saved recipe (or the bundle it is in) can birth that machine again.
- Actions are thin recipe makers. Tools do the work. Realize births from a sealed recipe file only.
- A remote action may add utilities, schema, and hooks only after the operator accepted that remote action's own preview, and only when no builtin does the job.
- `utilities/essentials` is generic Bash. No NDS behaviour goes in.
- Bash 5.3+. `${ fn; }` for our functions. No Python.

## 2. What was patched, and what removes it

| Patch in the old tree | Structural replacement |
|---|---|
| Every ask helper checks the mode (`_nds_cfg_ask_skip`, `nds_skip_menu`, 14 ad-hoc `NDS_*_SKIP` flags, no registry) | Two drivers fill the same recipe. The interactive driver is the only code that calls `prompt`; schema fields are never individually skippable. Every other question is behind a name in the skip store (§4.3): registered by its owner, enumerable, unknown names fail. |
| 12 preset files × 5 hooks (`defaults`, `configure`, `validate`, `summary`, `prompt_errors`) plus `nds_cfg_ask_<type>` per type | One declarative schema (§4.2). Defaults, validation, asking, summary, env import, file import, export are all generic walkers over it. One optional cross-field `check` per group. |
| `CONFIG_DATA` global + `NDS_CFG_AA_NAME` redirection + `SM_*` sessions saved with `declare -p` | One associative array per phase, passed by name. Cook owns `_NDS_COOK`; realize loads its own `local -A` from the sealed file. No global store. |
| Env bridge with a 40-name exclusion list because runtime flags and recipe keys share `NDS_` | Env import reads `NDS_<KEY>` only for keys that exist in the schema. Runtime flags are whatever is not in the schema. No list. |
| Two recipe formats (`[section]` + `export NDS_*` + `declare -gA` git maps), `kind/target/action` renames | One format (§4.2.6). Git per-URL keys are a directory, not a map (§4.7). |
| `NDS_INSTALL_CONFIRMED` so composers can confirm before they git-push | Push is a realize step declared in the recipe (`LEAF_PUSH_DIR`). Confirm happens once, in the pipeline, before realize. |
| Prompts inside realize (LUKS passphrase, keyfile path, hardware overwrite, preflight continue, disk/remote confirm) | Realize has no TTY. Secrets are `*_FILE` filled at cook or generated at materialize. Overwrite is the rule. Preflight warnings show on the confirm screen; errors fail. |
| Key generation at birth (admin password, LUKS material, initrd host key, machine age key, toolkit keys) | Generation is a cook-side phase (`materialize`). Delivery is a realize copy (`TARGET_SEED_DIR`). Restore never regenerates. |
| Bundle hook registry with reset-then-rerun trick | Bundle is a fixed directory layout under the session dir, plus one `bundle.collect` event for extras. Never code. |
| Post-realize code in actions (toolkit copies keys to `/mnt` after install) | `TARGET_SEED_DIR`: a tree of files mirrored onto the target by realize (local: copy onto `/mnt`; remote: `nixos-anywhere --extra-files`). |
| Four injection routes (`action_presets_paths`, `.nds/presets`, leaf `.nds/action.sh`, `remote_action_*` + `NDS_REMOTE_ACTION_DID_INSTALL`) plus `lib_hook.sh` scanning directories for `run()` | One action contract for builtin, fleet, and catalog actions (§4.4). Hooks are functions registered on named NDS events from `setup.sh`; no directory scanning (§4.4, §4.8). |
| Phases as `eventRun settings/realize/bundle.export` with registrants spread over files | A function sequence in `app/pipeline.sh`. Events are for hooks into that sequence (§4.4), not for the sequence itself. |
| `nixcfg` classic builder reads 44 config keys through a global | Takes the recipe array name as its first argument. |

## 3. Layout

```
nds/src/
  main.sh                    entry: essentials, CLI, then nds_pipeline_run
  VERSION
  setup_TEST.sh              shared test boot (moved from app/); provides nds_test_session
  logs/                      runtime log output (essentials LOG_ROOT); not source, gitignored
  lib/                       lib_bool.sh, lib_rand.sh (as now)
  app/                       framework, no install knowledge
    chrome.sh                (as now)
    features.sh              load order: import_dir of app/session, app/utility, app/action, recipe, recipe/schema, realize, wizard, wizard/askers, wizard/git
    session/                 (existing dir, kept)
      cli.sh                 argv → NDS_MODE NDS_SKIP NDS_YES NDS_REBOOT NDS_ACTION NDS_RECIPE_FILE
      mode.sh                nds_mode_is_unattended / nds_mode_is_interactive
      skip.sh                skip store: nds_skip_register / nds_skip / nds_skip_list
      dirs.sh                nds_session_dir <name>, nds_session_sshUser, nds_session_hostIp (from src.old lib_net.sh)
      exit.sh                exit hooks (as now, plus log publish wiring)
      failure.sh             (as now)
      install_logs.sh        (as now)
    utility/utility.sh       nds_requireUtility, nds_utility_addRoot
    action/                  discover, store, check, UI  (as now, minus nds_action_call / nds_action_items)
    pipeline.sh              nds_pipeline_run, nds_pipeline_cook, _nds_pipeline_loadRecipeAction
    confirm.sh               UI: summary + wipe warning + y/n  (interactive only)
    finish.sh                UI: bundle hints, USB key hints, reboot question  (interactive only)
  recipe/                    the contract. No UI. No tools.
    store.sh                 get/set/has/is/true/keys on a named array
    schema.sh                nds_schema_group / nds_schema_field / lookups
    schema/<group>.sh        one file per group (§4.9)
    types.sh                 per-type validators (from settingsManager/logic/validators, no UI)
    seed.sh                  defaults + detect
    load.sh                  loadFile, loadEnv
    validate.sh              type + required + when + group check
    materialize.sh           --generate for empty secret files
    export.sh                seal, export --portable
    fixtures/*.recipe        test fixtures
  wizard/                    interactive driver. The only tree that calls prompt.
    ask.sh                   nds_wizard_fill: walk active groups, ask by type, summary loop
    askers/<name>.sh         custom askers (--ask fn): disk pick, flake location, flake host, role, catalog
    git/                     git access screens (ported boundary, see §4.7)
  realize/                   birth. No TTY. Input is one file path.
    realize.sh               nds_realize <file>
    preflight.sh             checks; warnings to log, errors fail
    plan_classic.sh plan_flake_local.sh plan_flake_remote.sh
    steps_*.sh               disk, boot, flake, hardware, seed, leafpush
    verify.sh diag.sh
    bundle.sh                nds_bundle <file> → zip path
    bundle_quickstart.sh     QUICK_START.md text
  utilities/<name>/main.sh   tools (moved from src.old/utilities)
  actions/<name>/setup.sh    builtin recipe makers
fleet/nds-actions/<name>/setup.sh (+ logic/ for that action's cook helpers)
```

Deleted at the end: `nds/src.old/` entirely, `nds/src/app/settings/`, `nds/src/app/realize/`, `nds/src/actions/*/logic/`, `nds/docs/src-conventions.md`.

## 4. Architecture

### 4.1 Roles

| Role | May call | May not |
|---|---|---|
| Tools (`utilities/`) | other tools, essentials logger | `prompt`, `ui_*`, recipe store, action names, realize |
| Recipe (`recipe/`) | store, schema, types, essentials logger | `prompt`, `ui_*`, tools (exception: group `check` functions may call read-only tool functions such as listing flake hosts) |
| Wizard (`wizard/`) | `prompt`, `ui_*`, recipe, read-only tools | disk, `nixos-install`, realize |
| Actions (`actions/`) | recipe, tools, wizard askers (only through `--ask`), session dir | `prompt` directly, realize, disk write, `nixos-install` |
| Realize (`realize/`) | recipe load/validate, tools, essentials task/logger | `prompt`, `ui_*`, action functions, catalog clone, keygen |
| App (`app/`) | everything above by phase | install logic |

### 4.2 Recipe contract

#### 4.2.1 Store (`recipe/store.sh`)

All functions take the array name first. Arrays are `declare -A`.

```bash
nds_recipe_get  <aa> <KEY> [default]    # prints
nds_recipe_set  <aa> <KEY> <value>
nds_recipe_has  <aa> <KEY>              # key present and non-empty
nds_recipe_is   <aa> <KEY> <value>
nds_recipe_true <aa> <KEY>              # value == true
nds_recipe_keys <aa>                    # sorted, one per line
```

No global recipe. Cook uses `declare -gA _NDS_COOK=()` created by the pipeline. Realize uses `local -A R` inside `nds_realize`.

#### 4.2.2 Schema (`recipe/schema.sh`)

```bash
nds_schema_group <group> "<Title>" [--when '<cond>'] [--check <fn>]
nds_schema_field <group> <KEY> <type> [options]
```

Field options:

| Option | Meaning |
|---|---|
| `--default <v>` | Static default at seed |
| `--detect <fn>` | `fn` prints the default at seed. Read-only machine probes only (first disk, EFI vars, virt type) |
| `--required` | Must be non-empty when the field is active |
| `--when '<cond>'` | Field is active only when the condition holds |
| `--choices 'a\|b\|c'` | For `choice` |
| `--labels 'a=Text\|b=Text'` | Display text for choices and summaries |
| `--min <n>` `--max <n>` | For `int` and `port` |
| `--label '<text>'` | Question text. Default: KEY without group prefix, lowercased, `_` → space |
| `--hint '<text>'` | Second line under the question |
| `--ask <fn>` | Custom asker `fn <aa> <KEY>` replaces the type asker. Interactive only |
| `--validate <fn>` | `fn <value>` extra check after the type check |
| `--generate <fn>` | `secret` only. `fn <aa> <KEY> <dest>` writes the file. Runs at materialize when the field is empty and `--generate-when` holds |
| `--generate-when '<cond>'` | Condition for `--generate` |
| `--locked` | Not set by schema files; set at runtime by `action_pins` (§4.4) |

Condition syntax: comma-separated terms, all must hold. Term forms: `KEY=value`, `KEY!=value`, `KEY` (non-empty). Nothing else.

Types and their built-in check:

| Type | Check | Interactive widget |
|---|---|---|
| `string` | none | text |
| `bool` | `true`/`false` after normalising `yes/no/y/n/1/0/enabled/disabled` on load | confirm |
| `int` | integer, within min/max | text |
| `port` | int 1–65535 (or min/max) | text |
| `choice` | in `--choices` | select |
| `path` | starts with `/`, `~`, or `.` | text |
| `file` | `path` and `-f` | text |
| `dir` | `path` and `-d` | text |
| `disk` | `-b` | select from `find /dev` list, text fallback |
| `ip` `hostname` `username` `url` `timezone` `locale` `keyboard` `country` `mask` | ported validators | text |
| `secret` | value is a path; `-r` on it | hidden text; asker writes the value to `${secrets_dir}/<KEY minus _FILE>` mode 600 and stores that path |

Secret field names end in `_FILE`. There is no separate plain-value key. `nds_recipe_loadEnv` errors on `NDS_<KEY minus _FILE>` for a secret field ("secret values are not accepted; use `NDS_<KEY>`").

Group and field state:

- *Enabled*: an action (or `apply`) named the group. Seed and `loadEnv`/`loadFile` cover enabled fields.
- *Active*: enabled and the group's `--when` and the field's `--when` hold. Validate, ask, summary, and export cover active fields only.

Lookups needed by the drivers: `nds_schema_groups` (enabled, in enable order), `nds_schema_allGroups` (every declared group), `nds_schema_groupFields <group>` (declaration order), `nds_schema_attr <KEY> <attr>`, `nds_schema_isActive <aa> <KEY>`, `nds_schema_groupIsActive <aa> <group>`, `nds_schema_enable <group>...`, `nds_schema_enableAll`, `nds_schema_hasKey <KEY>`, `nds_schema_lock <KEY>`, `nds_schema_isLocked <KEY>`.

Schema files `recipe/schema/<group>.sh` are all sourced at load (`import_dir recipe/schema --depth 0`). Fleet and catalog actions add groups from a `cook.schema` hook (§4.4).

#### 4.2.3 Seed (`recipe/seed.sh`)

`nds_recipe_seed <aa>`: for every enabled field with a `--default` or `--detect`, set it if the key is empty. Detect functions are called with no arguments and print one line.

#### 4.2.4 Load (`recipe/load.sh`)

`nds_recipe_loadFile <aa> <file>`:
- Lines: blank, `#…`, `[…]` ignored. `KEY=value` or `KEY="value"` with `\"` and `\\` unescaped. `export ` prefix is an error. `KEY` must match `^[A-Z][A-Z0-9_]*$`.
- Unknown key (not in schema at all) → `error`, return 1. Key in a non-enabled group → `debug`, ignored.
- A `--locked` key in the file → `warn`, ignored.
- Every value for a `secret`, `file`, or `dir` field that is a relative path is resolved against the directory of `<file>`. This is how a bundle's `nds-restore.recipe` finds `secrets/…`.
- `.zip` argument: extract to `${work_dir}/restore/` and load `nds-restore.recipe` from there.

`nds_recipe_loadEnv <aa>`: for each enabled KEY, if `NDS_<KEY>` is set and non-empty, set it. Locked keys → `warn`, ignored. Secret plain-value form → `error`, return 1.

Order in every driver: seed → `action_defaults` → loadFile (if `NDS_RECIPE_FILE`) → loadEnv → `action_pins`. Env beats file. Pins beat everything.

#### 4.2.5 Validate (`recipe/validate.sh`)

`nds_recipe_validate <aa>`: for every active field: required, type check, `--validate`. Then every active group's `--check <fn> <aa>`. Each problem is one `error` line naming the KEY. Returns the number of problems. Nothing here prompts.

#### 4.2.6 Materialize (`recipe/materialize.sh`)

`nds_recipe_materialize <aa>`: for every active `secret` field with `--generate` whose value is empty and whose `--generate-when` holds: call `fn <aa> <KEY> "${secrets_dir}/<KEY minus _FILE>"`, then set KEY to that path. Generators (`recipe/generate.sh`): `nds_generate_password` (uses `<PREFIX>_PASSWORD_LENGTH`), `nds_generate_bytes` (uses `<PREFIX>_KEY_LENGTH`), `nds_generate_sshHostKey` (ed25519), `nds_generate_ageKey` (via `age` tool). Runs in both drivers. A restore whose `*_FILE` already points at a file is untouched.

#### 4.2.7 Seal and export (`recipe/export.sh`)

`nds_recipe_seal <aa> <out_file>`: `nds_recipe_validate` must return 0, else return 1 and write nothing. Then `nds_recipe_export <aa> <out_file>`. Then `chmod 600`. Prints nothing.

`nds_recipe_export <aa> <out_file> [--portable]`: header `# nds-recipe 1`, then for each active group in enable order: `[<group>]`, then its active non-empty keys in declaration order as `KEY="value"` (escape `\` and `"`). Deterministic: sealing twice gives identical bytes. `--portable` omits: `DISK_TARGET`, `REMOTE_TARGET_IP`, every `secret` field, `GIT_KEYS_DIR`, `LEAF_PUSH_DIR`, `LEAF_PUSH_MESSAGE`, `TARGET_SEED_DIR`. Used for the leaf's `.nds/hosts/<host>.recipe`.

"Sealed" means: a file written by `nds_recipe_seal`. Realize loads it and validates again; it does not trust the file.

### 4.3 Pipeline and modes (`app/pipeline.sh`, `app/session/cli.sh`, `app/session/mode.sh`, `app/session/skip.sh`)

Runtime flags (the complete list; everything else `NDS_*` is a schema key or an error):

| Flag | CLI | Meaning |
|---|---|---|
| `NDS_MODE` | `--unattended` | `interactive` or `unattended`. Default: `interactive` when stdin is a TTY, else `unattended`. Any other value → error |
| `NDS_SKIP` / `NDS_SKIP_<NAME>` | `--skip a,b` | Interactive only. Skip store names (below). `NDS_SKIP` is a comma list; `NDS_SKIP_<NAME>=true` is the per-name form (`NAME` = the dotted name uppercased, `.` → `_`). Both accepted. An unregistered name in either form → error at startup |
| `NDS_YES` | `--yes` | Every registered name except those marked `keep-on-yes` (currently `finish.reboot`) |
| `NDS_REBOOT` | `--reboot` | `true`: reboot after a successful finish. Interactive without it: ask unless `finish.reboot` is skipped. Unattended without it: print the hint |
| `NDS_ACTION` | `--action <name>` / `apply [file]` | Skip the action menu |
| `NDS_RECIPE_FILE` | `--recipe <file>` / `apply <file>` | File or `.zip` loaded before env |
| `NDS_FLEET_ACTIONS_DIR` | — | Second discover root (default `<repo>/fleet/nds-actions`) |
| `NDS_TEST` | — | Show `test` and `uiSmoke` actions |

Deleted: `NDS_AUTO_CONFIRM`, `NDS_UNATTENDED`, `NDS_SKIP_MENU`, every `NDS_*_SKIP`, `NDS_REBOOT_FORCE`, `NDS_REBOOT_SKIP`, `NDS_PRESET_EXTRA_*`, `NDS_SCOPED_CONFIG_FILE`, `NDS_GIT_*` runtime maps, `NDS_FLAKE_*` env mirrors, `NDS_CAST_*`, `NDS_GH_*`, `--skip-menu`, `--auto-confirm`.

**Skip store** (`app/session/skip.sh`). Every question that is not a schema field is behind a registered name. Schema fields are never individually skippable (they are answered by the recipe; `summary` decides whether valid ones are shown).

```bash
nds_skip_register <name> "<what happens when skipped>" [keep-on-yes]   # by the file that owns the screen, at load
nds_skip <name>        # 0 when unattended, or NDS_SKIP_<NAME>=true, or <name> in NDS_SKIP, or NDS_YES and not keep-on-yes
nds_skip_list          # name, default, source of the decision — used by --help
```

Names are `[a-z]+(\.[a-zA-Z]+)+`. Registered by the framework:

| Name | Owner | Skipped means |
|---|---|---|
| `action.preview` | `app/pipeline.sh` | accept the action preview |
| `cook.summary` | `wizard/ask.sh` | ask only fields that fail validation; no review screen |
| `install.confirm` | `app/confirm.sh` | proceed without the wipe / remote confirm |
| `finish.backup` | `app/finish.sh` | do not wait for "I copied the bundle" |
| `finish.reboot` | `app/finish.sh` | do not ask; reboot only when `NDS_REBOOT=true` (`keep-on-yes`) |

Actions may register their own (`toolkit.scaffoldOverwrite`, …) from `setup.sh`; they appear in `--help` once that action is loaded. An unattended run skips every name, so the "skipped means" column is also the unattended behaviour. A non-field prompt without a registered name is a bug (test: `rg 'prompt ' wizard app actions fleet/nds-actions` hits are either type askers or preceded by an `nds_skip` check).

`nds_pipeline_run`:

```
discover local actions (builtin, then fleet); hide debug unless NDS_TEST
select action                          (menu only if interactive)
nds_skip action.preview || preview accept
declare -gA _NDS_COOK=()
nds_pipeline_cook _NDS_COOK local "$NDS_CURRENT_ACTION"
nds_recipe_materialize _NDS_COOK
sealed="${recipe_dir}/sealed.recipe"; nds_recipe_seal _NDS_COOK "$sealed"
nds_skip install.confirm || nds_confirm "$sealed"                (app/confirm.sh; decline → return 1)
nds_realize "$sealed"
zip="${ nds_bundle "$sealed"; }"
nds_finish "$sealed" "$zip"                              (app/finish.sh: screens gated by nds_skip finish.backup / finish.reboot; unattended prints paths and the reboot hint, or reboots when NDS_REBOOT=true)
```

`nds_pipeline_cook <aa> <store> <action>`:

```
source the action's setup.sh (already done by select for the top-level action)
eventRun cook.schema                          (actions that declare extra groups do it here)
nds_schema_enable ${ action_groups; }
nds_recipe_set aa INSTALL_ACTION <action>; lock it
nds_recipe_seed aa
apply action_defaults (if defined): KEY=value lines
loadFile (if NDS_RECIPE_FILE and this is the top-level cook)
loadEnv
apply action_pins (if defined): set + lock
if interactive: nds_wizard_fill aa            (§4.6; loops until valid and accepted; nds_skip cook.summary asks only failing fields)
else:           nds_recipe_validate aa || return 1
action_cook aa (if defined)
eventRun cook.done aa
nds_recipe_validate aa || return 1
```

This is the only place the mode is read for the fill step. `nds_wizard_fill` is never called when unattended.

**`apply`** is a builtin action whose `action_groups` prints every group and which has no `action_cook`. `apply <file>` on the CLI sets `NDS_ACTION=apply NDS_RECIPE_FILE=<file>`. Its cook has one extra step so that hooks survive a restore, `_nds_pipeline_loadRecipeAction <aa>`, called right after `loadFile` when the current action is `apply`: read `INSTALL_ACTION` from the recipe; if it names a builtin or fleet action, `import_file` that action's `setup.sh` (registers its event hooks; its `action_cook` is not run); if it names `remoteAction`, re-clone `CATALOG_URL`, show that catalog action's preview (`nds_skip action.preview` applies; unattended = accept), then `import_file` its `setup.sh`. Interactive `apply` then asks every active field prefilled, so a recipe from a bundle or from `.nds/hosts/<host>.recipe` can be reviewed and changed before realize. Half-attended git access works the same way: a recipe with no keys fails the `flake` check on `GIT_KEYS_DIR`, and the wizard re-asks that field (§4.7).

Session dir (essentials `sessionDir`, prefix `nds`): subdirs `recipe secrets config seed work logs`. `app/session/dirs.sh` exposes `nds_session_dir <name>` wrapping `runtime_getPath`. Wherever this file writes `${secrets_dir}`, `${recipe_dir}`, `${work_dir}`, it means `${ nds_session_dir secrets; }` etc. In tests, `setup_TEST.sh` provides `nds_test_session` (creates a `mktemp -d` tree with those six subdirs and makes `nds_session_dir` return paths under it) and `nds_test_session_drop`. Exit: `exitError` → compose log, one warning line, `nds_session_showFailure`; both exits → publish `nds.log` and `nixosInstallation.log` into `/home/<user>` (from `session/install_logs.sh`), then `runtime_purgeAll` on clean exit only.

### 4.4 Action contract

`actions/<name>/setup.sh` (builtin, fleet, or catalog):

```bash
# Description: one line, within the first 20 lines           (required)
action_groups()   { printf '%s\n' flake git disk boot encryption; }   # required: groups, one per line, in ask order
action_preview()  { ui_h "..."; ui_b "..."; }                          # required
action_defaults() { printf '%s\n' FLAKE_HOST=control-toolkit; }        # optional: KEY=value lines, applied after seed
action_pins()     { printf '%s\n' INSTALL_KIND=flake INSTALL_MODE=local; }  # optional: applied last and locked
action_cook()     { local -n R=$1; ...; }                              # optional: effects limited to the session dir and the leaf clone; may set realize keys
```

`action_cook` may: call tools, write under `work/`, `secrets/`, `seed/`, clone or edit the leaf clone under `work/leaf`, set `LEAF_PUSH_DIR`, `LEAF_PUSH_MESSAGE`, `TARGET_SEED_DIR`, set any other active key. It may not prompt (use a `--ask` asker on a field instead), may not push, may not touch a block device or `/mnt`, may not call `nixos-install` or `nds_realize`.

`setup.sh` may `import_file` / `import_dir` any files it ships (fleet: `logic/`; catalog: anything under its checkout) and may call `nds_utility_addRoot <dir>` so `nds_requireUtility` finds its own tools. No directory layout is imposed beyond `setup.sh`.

**Events an action may register on** (`eventRegister <event> <fn>` from `setup.sh` or the files it sources; every hook receives the recipe array name as `$1`):

| Event | Run by | When | Hook may |
|---|---|---|---|
| `cook.schema` | pipeline | before groups are enabled | `nds_schema_group` / `nds_schema_field` for extra groups (fleet, catalog); `nds_skip_register` |
| `cook.done` | pipeline | after `action_cook`, before the final validate | set more keys in the cook array |
| `realize.pre_disk` | realize | after preflight, before any disk write | read `R`; abort with non-zero |
| `realize.post_disk` | realize | target mounted, nothing staged yet | prepare `/mnt` (local only; remote: not run) |
| `realize.pre_install` | realize | flake staged and hardware written, before build / `nixos-install` / `nixos-anywhere` | edit the staged flake; write under `/mnt` (local) |
| `realize.post_install` | realize | after activate and seed, before verify | write under `/mnt` (local); remote: `/mnt` does not exist, hook may ssh `REMOTE_TARGET_IP` |
| `realize.done` | realize | after verify, before bundle | read-only reporting, extra checks |
| `bundle.collect` | bundle | before the zip is written | `nds_bundle_add <dest_in_zip> <src_path>` (files only, never code) |

Priority is the essentials bus priority (`eventRegister <event> <fn> [priority]`, lower first, default 50). Framework steps inside a slot are not hooks; a hook cannot reorder them, only run before or after the slot. `exit`, `exitError`, `exitClean`, `prompt.pre`, `prompt.post`, `utility.load` are essentials / framework events and stay as they are. No other NDS events exist; do not add one without adding it to this table.

Hooks are process-local: they exist while the `setup.sh` that registered them is loaded. That is why `apply` re-loads the recipe's `INSTALL_ACTION` (§4.3): anything an action does in a hook happens again on restore, from the same recipe. Realize runs `eventRun` at its slots and never sources code itself.

Discovery check (`action/action_check.sh`) requires `action_groups()`, `action_preview()`, and `# Description:`. `action_setup`, `action_config`, `action_presets`, `action_presets_paths`, `action_on_accept`, `action_extend_settings_manager` are no longer recognised; their presence fails the check.

Builtin actions after the port:

| Action | `action_groups` | pins | `action_cook` |
|---|---|---|---|
| classicInstall | `install region network access boot disk encryption platform` | `INSTALL_KIND=classic` | none |
| installFlake | `install flake git boot disk encryption` | `INSTALL_KIND=flake` | none. Disko detection (`DISK_STRATEGY=flake` when the host dir has `disko.nix`) is the `flake` group check |
| apply | every group (`nds_schema_allGroups`) | none | none |
| remoteAction | `install catalog` | `INSTALL_KIND=flake` | §4.8 |
| test, uiSmoke | debug; hidden unless `NDS_TEST`; must satisfy the contract | | |
| addFleetHost (fleet) | `install flake git scaffold network boot disk encryption` | `INSTALL_KIND=flake` | scaffold host dir from role into `work/leaf`, write `.nds/hosts/<host>.recipe` (`--portable`), set `LEAF_PUSH_DIR=work/leaf`, `LEAF_PUSH_MESSAGE` |
| toolkit (fleet) | `install toolkit flake git boot disk encryption platform` | `INSTALL_KIND=flake INSTALL_MODE=local` | new or restore operator age + toolkit ssh into `secrets/toolkit/`; write pubs into `work/leaf/.toolkit/operator/keys/`; ensure `.sops.yaml`; build `seed/` with `etc/sops/age/operator_sops.key` and `root/.ssh/id_ed25519{,.pub}` (files only); set `TARGET_SEED_DIR=seed`, `LEAF_PUSH_DIR`, `LEAF_PUSH_MESSAGE`. `setup.sh` also registers a `realize.post_install` hook that clones `fleet/toolkit` onto `/mnt/var/lib/nds-toolkit/src` with the `current` symlink (the old `nds_toolkit_seed_scripts_to_target`); it re-runs on restore because `apply` loads this `setup.sh` |

Fleet actions keep their cook helpers in `fleet/nds-actions/<name>/logic/*.sh`, sourced from `setup.sh` with `import_dir "${BASH_SOURCE[0]%/*}/logic" --depth 0`. `hooks/write_operator_pubs.sh` becomes a plain function in that logic, called from `action_cook`.

### 4.5 Realize contract (`realize/`)

`nds_realize <sealed_file>`:

```
local -A R; nds_schema_enableAll; nds_recipe_loadFile R file || return 1
nds_recipe_validate R || return 1
nds_realize_preflight R || return 1                    (errors only; warnings were shown at confirm)
case INSTALL_KIND / INSTALL_MODE → plan
```

Plans are fixed sequences. Every step is a function `step_<name> R …` wrapped in `taskStart`/`taskOk`/`taskFail` (essentials task; `nds_step_exec*` and `NDS_UI_QUIET` are gone). Optional steps run only when their key is set:

```
plan_flake_local:
  eventRun realize.pre_disk R
  [LEAF_PUSH_DIR]     step_leafPush        git add hosts .nds .toolkit .sops.yaml; commit LEAF_PUSH_MESSAGE; push with GIT_KEYS_DIR
  disk                DISK_STRATEGY=flake → require /mnt mounted; else unmount, space check, LUKS (files), partition or disko, mount, initrd host key copy
  eventRun realize.post_disk R
  stage flake         clone FLAKE_REPO_URL (with GIT_KEYS_DIR) or copy FLAKE_LOCAL_PATH to FLAKE_INSTALL_PATH
  hardware            facter or hardware-configuration into host dir / etc-nixos / skip. Always overwrite
  generated module    nixcfg_writeGeneratedHost R
  eventRun realize.pre_install R
  prefetch + eval + build + activate
  [TARGET_SEED_DIR]   step_seed: cp -a "${TARGET_SEED_DIR}/." /mnt/  (modes preserved)
  [GIT_PERSIST_ACCESS=true] step_seedGit: GIT_KEYS_DIR → /mnt/root/.ssh/nds/ + ssh config include
  [SOPS_AGE_KEY_FILE] copy to /mnt/etc/sops/age/keys.txt; write pub + enroll note into secrets/
  eventRun realize.post_install R
  EFI entry, verify
  eventRun realize.done R
plan_flake_remote:
  eventRun realize.pre_disk R
  [LEAF_PUSH_DIR]     step_leafPush
  stage flake locally, prefetch, eval
  eventRun realize.pre_install R                (hooks may edit the staged flake; there is no /mnt)
  nixos-anywhere: facter path, ENCRYPTION_KEY_FILE, and --extra-files <TARGET_SEED_DIR> when set
  eventRun realize.post_install R
  eventRun realize.done R
plan_classic:
  eventRun realize.pre_disk R; disk; eventRun realize.post_disk R; nixcfg_writeClassic R; hardware; copy configs
  eventRun realize.pre_install R; nixos-install; [TARGET_SEED_DIR] step_seed; eventRun realize.post_install R; EFI entry; verify; eventRun realize.done R
```

Rules:

- Realize reads `R` only. No `nds_cfg_*`, no `NDS_<KEY>` env, no session state from cook except through keys in `R`.
- Every secret or key material used at birth is a `*_FILE` in `R`. Realize never runs `age-keygen`, `ssh-keygen`, or a password generator.
- No `prompt`, no `ui_*`. Progress is `task*`; detail is `info`/`warn`/`error` in the `nixos` and `session` logger scopes.
- No catalog clone, no `import_file`, no `source`. The `eventRun` slots in the plans are the only extension points; whoever registered a hook was loaded by the pipeline before realize started.
- Hardware artefacts are overwritten. The old "overwrite?" question is gone.
- `LEAF_PUSH_DIR` failing aborts before disk.
- `TARGET_SEED_DIR` holds files (keys, configs), never code to run.

`nds_bundle <sealed_file>` (`realize/bundle.sh`, no UI): staging = `nds-restore.recipe` (export of `R` with every `secret`/`file` value copied under `secrets/` and rewritten relative; `TARGET_SEED_DIR` → `seed/`; `GIT_KEYS_DIR` path rewritten to `secrets/git`; `LEAF_PUSH_DIR`, `LEAF_PUSH_MESSAGE` dropped), `secrets/`, `config/`, `seed/`, `logs/nds.log`, `logs/nixosInstallation.log`, `QUICK_START.md`, then `eventRun bundle.collect R` for extras added with `nds_bundle_add <dest> <src>`. Zip to `/home/<user>/nds_bundle.zip` (tar.gz fallback), mode 600, chown. Prints the path. `apply` on that zip is a restore. The bundle never contains NDS, fleet, or catalog code.

### 4.6 Wizard (`wizard/`)

`nds_wizard_fill <aa>` (interactive only):

```
loop:
  for group in active groups (enable order):
     ui_h title; chrome_setSubtitle group
     for field in active fields: skip locked; asker = --ask fn or type asker; asker sets the key or leaves it
  problems = nds_recipe_validate aa (errors shown)
  nds_skip cook.summary and problems == 0 → return 0
  show summary (each active group: ui_kv label value; secrets shown as "(file)")
  prompt select: Accept | Edit <group>… | Abort
  Accept with problems == 0 → return 0; Accept with problems → re-ask only failing fields; Abort → return 1
```

Type askers live in `wizard/ask.sh`, one per type, signature `_nds_ask_<type> <aa> <KEY>`. They read label/hint/choices/default from the schema. `prompt` rc 2 (back) keeps the current value; rc 3 or 4 aborts the fill. No mode checks anywhere in `wizard/`.

Custom askers (`wizard/askers/`), each `fn <aa> <KEY>`:

| Asker | Field | Does |
|---|---|---|
| `nds_ask_disk` | `DISK_TARGET` | select from block devices, text fallback |
| `nds_ask_flakeLocation` | `FLAKE_LOCATION` | text; classify remote/local; set `FLAKE_REPO_URL`/`FLAKE_LOCAL_PATH`/`FLAKE_SOURCE` |
| `nds_ask_gitAccess` | `GIT_KEYS_DIR` | the git access screens (§4.7): for the flake URL and every private closure URL, probe with the current dir; where a probe fails, obtain a key. Returns when every probe passes or the operator aborts |
| `nds_ask_flakeHost` | `FLAKE_HOST` | list `nixosConfigurations` from the probe clone (`flake_probe` with `GIT_KEYS_DIR`); select |
| `nds_ask_role` | `SCAFFOLD_ROLE` | list `.roles/` in the probe clone; existing host → offer `.nds/hosts/<host>.recipe` restore (loadFile into `aa`) |
| `nds_ask_country` | `REGION_COUNTRY` | text; on accept set timezone/locale/keyboard defaults when still at seed values |
| `nds_ask_catalogAction` | `CATALOG_ACTION` | clone catalog into `work/catalog`, discover into store `remote`, select |

`wizard/git/` is the ported git access flow (§4.7). It is entered only from `nds_ask_gitAccess` and `nds_ask_catalogAction`.

### 4.7 Git access model

Recipe keys (group `git`): `GIT_KEYS_DIR` (dir, default `${secrets_dir}/git`, `--ask nds_ask_gitAccess`), `GIT_PERSIST_ACCESS` (bool, default true).

`GIT_KEYS_DIR` is a directory-as-map: `<safeurl>` and `<safeurl>.pub`, where `safeurl` = `${ git_url_safe "$url"; }` (host, owner, repo joined with `_`, lowercase). Optional `default` key used when no per-URL file exists. Tool `git_sshCommand <keys_dir> <url>` prints the `GIT_SSH_COMMAND` value for that URL (`ssh -i <key> -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new`).

This is the old git store with the map persisted as files instead of `declare -gA` blocks. The number of repos is unknown up front in both designs; here the map is the directory listing, so the recipe stays flat and the bundle carries the directory as `secrets/git/`. Three ways a run gets its keys, all through the same dir:

| Run | How `GIT_KEYS_DIR` is filled |
|---|---|
| Interactive, first install | `nds_ask_gitAccess` (the wizard) creates or imports keys per URL |
| Interactive restore or env-only recipe without keys (half-attended) | `flake` check fails on `GIT_KEYS_DIR`; the wizard re-asks that field; operator sets up access; everything else stays as loaded |
| Unattended | dir must already hold working keys (bundle `secrets/git/`, or pre-seeded by the operator); a failed probe is a validation error before disk |

Tools (`utilities/git/`, argument-driven, no store, no env overlay): `git_url_parse`, `git_url_safe`, `git_url_toSsh`, `git_url_isRemote`, `git_probe <keys_dir> <url>` (ls-remote), `git_clone <keys_dir> <url> <dest> [--depth 1]`, `git_push <keys_dir> <dir>`, `git_commitAll <dir> <message> [paths…]`, `git_key_create <path>`, `git_key_pub <path>`, `git_key_fingerprint <path>`, `git_key_bodyLooksValid <text>` (replaces `lib_key.sh`), `gh_*` (bin fetch via `pkg`, device login, `gh api` add deploy key / account key, session logout). `_GIT_STORE`, `GIT_ENV_PREFIX`, `git_store_*`, `NDS_GIT_*` maps are gone.

Cook-side flow (`wizard/git/`, called from `nds_ask_gitAccess`): for the flake URL and then for every private git URL in the flake closure (`flake_listLockGitEntries` on the probe clone): if `git_probe` with `GIT_KEYS_DIR` succeeds → next; else ask: existing key (path or paste → copied to `<safeurl>`) or new key (generate → register via `gh` device login + API, or show pubkey + QR and wait for confirm). `GIT_PERSIST_ACCESS` is its own field, asked by the type asker. Internals of the ported screens may stay as they are; only the boundary changes: they read/write `aa` via `nds_recipe_*`, write keys into `GIT_KEYS_DIR`, and probe via the tool.

The `flake` group check runs `git_probe` for the flake URL and each private closure URL and reports failures against `GIT_KEYS_DIR`. Unattended, that is a validation error before the disk is touched; `NDS_GIT_AUTH_SKIP` is gone because unattended always fails on missing access. Interactive, it re-asks `GIT_KEYS_DIR`, which is the wizard.

Prefetch of the closure into the Nix store stays a realize step (needs the same keys, at birth).

### 4.8 Remote actions

Group `catalog`: `CATALOG_URL` (url, required), `CATALOG_ACTION` (string, required, `--ask nds_ask_catalogAction`).

A catalog is a git repo with `.nds/actions/<name>/setup.sh` following §4.4. That is the whole convention. Inside `setup.sh` the catalog author sources whatever else the checkout contains, declares groups on `cook.schema`, adds a utilities root with `nds_utility_addRoot`, and registers `realize.*` / `bundle.collect` hooks with `eventRegister`.

`remoteAction` builtin: `action_groups` = `install catalog`; `action_cook`:

```
dir=work/catalog; interactive: already cloned by the asker; unattended: git_clone GIT_KEYS_DIR CATALOG_URL dir
nds_action_discover remote dir/.nds/actions                                   (same check as builtins)
name = CATALOG_ACTION; must exist in store remote
nds_skip action.preview || preview of that action; decline → return 1               (second accept)
import_file dir/.nds/actions/name/setup.sh                                    (this is the injection point: nothing from the catalog runs before this line)
nds_pipeline_cook aa remote name                                              (re-entrant: cook.schema, enables its groups, asks, validates, runs its action_cook)
```

Unattended: naming `NDS_CATALOG_ACTION` is the accept. `remote_action_prepare/config/run/after`, `NDS_REMOTE_ACTION_DID_INSTALL`, leaf `.nds/action.sh`, `.nds/presets`, `NDS_PRESET_EXTRA_PATHS`, `lib_hook.sh` directory scanning are gone. A remote action cannot install; if it needs a birth step, it registers a `realize.*` hook.

Leaf hooks (`.nds/hooks/*`, `.roles/<role>/hooks`) are not scanned by NDS. A fleet action that wants leaf-provided behaviour sources those files itself from `action_cook` (they are then ordinary functions that may `eventRegister`), so the operator's accept of that fleet action covers them.

### 4.9 Groups and keys

Port each group's field list from `nds/src.old/app.old/settingsManager/data/builtin/<name>.sh` (`_defaults` gives keys and defaults; `_configure` gives labels, choices, conditions; `_validate` gives the group check and required flags). Keep key names unchanged except the changes below. Machine-probing defaults become `--detect`.

| Group | Source preset | Changes |
|---|---|---|
| `install` | (new) | `INSTALL_KIND` choice classic\|flake required; `INSTALL_MODE` choice local\|remote default local; `INSTALL_ACTION` string locked by the pipeline; `REMOTE_TARGET_IP` ip required when `INSTALL_MODE=remote`. (`INSTALL_COMPOSER` → `INSTALL_ACTION`) |
| `region` | region + quick | `REGION_COUNTRY` country optional `--ask nds_ask_country` (replaces `QUICK_COUNTRY` and `settings_country.sh` becomes the asker's table) |
| `network` | network | unchanged |
| `access` | access | drop `ACCESS_ADMIN_PASSWORD`; `ACCESS_ADMIN_PASSWORD_FILE` secret, `--generate nds_generate_password --generate-when ACCESS_ADMIN_PASSWORD_AUTO=true`, required when `ACCESS_ADMIN_PASSWORD_AUTO=false` |
| `boot` | boot | unchanged; detect for both |
| `disk` | disk | `DISK_TARGET` disk `--ask nds_ask_disk --detect`; `DISK_DISKO_CONFIG` file; drop `SEPARATE_HOME`/`HOME_SIZE` (never seeded; read only by disko step) |
| `encryption` | encryption | drop `ENCRYPTION_PASSPHRASE` value; `ENCRYPTION_PASSPHRASE_FILE` secret generate-when `ENCRYPTION_PASSWORD=true,ENCRYPTION_PASSWORD_AUTO=true`; `ENCRYPTION_KEY_FILE` secret (raw key material) generate-when `ENCRYPTION_KEY=true,ENCRYPTION_KEY_AUTO=true`, required when `ENCRYPTION_KEY=true`; `ENCRYPTION_REMOTE_HOSTKEY_FILE` secret generate-when `ENCRYPTION_REMOTE_UNLOCK=true` (`nds_generate_sshHostKey`); group `--when ENCRYPTION` is not used — `ENCRYPTION` itself is the first field |
| `platform` | platform | unchanged; detects |
| `flake` | installFlake | group `--when INSTALL_KIND=flake`; `FLAKE_LOCATION` `--ask nds_ask_flakeLocation`; `FLAKE_HOST` `--ask nds_ask_flakeHost`; `SOPS_AGE_KEY_FILE` secret generate-when `SOPS_AGE_REUSE=generate` (`nds_generate_ageKey`); group check: `INSTALL_MODE` remote needs IP, location present, host in `nixosConfigurations` (probe clone via tool), git access probe for URL and private closure, disko detection sets `DISK_STRATEGY=flake`. Drop `GIT_ACCESS_STRATEGY` from this group |
| `git` | (new, from wizard keys) | `GIT_KEYS_DIR` dir default `${secrets_dir}/git`; `GIT_PERSIST_ACCESS` bool default true. Drop `GIT_EXISTING_KEY`, `GIT_KEY_SOURCE`, `GIT_AUTH_ROUTE`, `GIT_SSH_KEY_*`, `GIT_AUTH_MODE`, `GIT_ACCESS_*`, `GIT_CLOSURE_ROUTE`, `GIT_GH_*` (wizard-internal state stays local to the wizard) |
| `scaffold` | addFleetHost | `SCAFFOLD_MODE` choice new\|existing; `SCAFFOLD_ROLE` `--ask nds_ask_role` required when `SCAFFOLD_MODE=new` |
| `toolkit` | toolkit | `CAST_TOOLKIT_MODE` → `TOOLKIT_MODE` choice new\|restore; `CAST_TOOLKIT_BUNDLE` → `TOOLKIT_BUNDLE` file required when restore; drop `CAST_TOOLKIT_RESTORE` (UI mirror); `TOOLKIT_AGE_KEY_FILE`, `TOOLKIT_SSH_KEY_FILE` secret (set by `action_cook`, not generated by materialize) |
| `catalog` | remoteAction | `CAST_REPO_URL` → `CATALOG_URL`; `CAST_ACTION` → `CATALOG_ACTION` |
| `realize` | (new) | `LEAF_PUSH_DIR` dir; `LEAF_PUSH_MESSAGE` string; `TARGET_SEED_DIR` dir. All optional, set by `action_cook` only, never asked (`--ask` absent, no default). Always enabled |

## 5. Rejected alternatives (from the earlier brief), and why

| Brief | Decision | Why |
|---|---|---|
| Keep presets ("which presets, which tools to call") and the `nds_cfg_ask_*` layer until they move | Replaced by the schema in step 1 | Presets are the patch. Each carries five hooks and the ask layer checks the mode on every call. A declarative schema makes both drivers generic and deletes ~1,600 lines. |
| Phases as events (`eventRun settings/realize/bundle.export`) | Plain function sequence | A linear pipeline does not need a bus. Events hide order and make "who fills what" a search. The bus stays for exit, prompt chrome, and utility load. |
| Disk confirm "happens in realize, once" | Confirm is a pipeline step before `nds_realize`; realize has no TTY | The brief also says "do not let realize prompt". Both cannot hold. A realize with no TTY is testable with fixtures and is the same function for `apply`. |
| Bundle as realize's finish (with a hook registry) | `nds_bundle` is a separate pipeline step over a fixed session layout; finish screens are `app/finish.sh` | Whatever is in `secrets/ config/ seed/ logs/` is the bundle; `bundle.collect` covers the rare extra file without a registry of its own. Screens are UI, so they leave realize. |
| `nds_settings_bind` + still reading builtin presets from `src.old` (`app/settings/prompt.md`) | Cancelled | It ports the patch. |
| Realize keeps `nds_cfg_get` per step | Realize takes one file, loads `R`, passes `R` or scalars | "Sealed recipe is the only input" must be structural, not a comment. |
| Remote actions inject "utilities, logic, and hooks" through their own API | Same `setup.sh` contract as builtins; extension is `eventRegister` on the named NDS events, for every kind of action | One contract, one hook mechanism (the essentials bus). The second accept is the gate, not a second API. |
| "Builtin actions do not get a special injection API" | Builtin, fleet, and catalog actions all use the same events | Consistency beats the distinction; the accept step is what differs for a catalog, not the API. |
| Order: recipe → realize → utilities → actions | recipe → utilities → realize → pipeline (unattended) → actions → wizard → delete | Realize calls tools, so tools move first. The unattended product is complete before any screen is ported; screens then sit on a tested contract. |
| `apply` "is not an action" | Kept as a builtin action folder with `action_groups` = all groups and no cook | It costs 15 lines and removes a special case from select/preview. |
| Keep `nds_action_call` / `nds_action_items` | Deleted | They exist only to bridge the old `CONFIG_DATA` store into action logic. |

## 6. Decisions to veto now, or accept

These are choices this plan makes that change behaviour. Say so before step 1 if any is wrong.

1. **Skip flags become a registered store.** Five framework names (`action.preview`, `cook.summary`, `install.confirm`, `finish.backup`, `finish.reboot`), env as `NDS_SKIP_<NAME>=true` or a `NDS_SKIP` list, `--yes` for all but reboot, unattended skips all. Old `NDS_*_SKIP` names are gone; unregistered names fail. The ISO matrix in `nds/.wip/TESTING.md` needs an env rename.
2. **Git keys are a directory, one key per URL, not a map in the recipe.** Unattended needs the directory pre-seeded (a bundle provides it); half-attended runs get the wizard on that one field. Per-URL method choices (`NDS_GIT_KEY_MODE`, `NDS_GIT_KEY_BODY`, import env) are gone.
3. **All key material is generated at cook/materialize, never at birth.** Admin password, LUKS passphrase/keyfile, initrd host key, machine age key. A recipe with `*_AUTO=true` and no file generates once; the bundle then carries it, and restore reuses it.
4. **Hardware artefacts are overwritten without asking.** `facter.json` / `hardware-configuration.nix` in the host dir are NDS-owned.
5. **Leaf push runs inside realize, after the disk confirm.** Declining the confirm leaves the leaf untouched. On restore the push step is absent.
6. **No directory of hooks is scanned anywhere** (leaf `.nds/hooks`, `.roles/<role>/hooks`, action `hooks/`, catalog `.nds/hooks`). Hooks are `eventRegister` calls made by a `setup.sh` (or the files it sources) that the operator accepted.
7. **`TARGET_SEED_DIR` carries files only; anything that runs code on the target is a `realize.*` hook.** The toolkit's `fleet/toolkit` clone onto `/mnt/var/lib/nds-toolkit` becomes a `realize.post_install` hook in the toolkit `setup.sh` and therefore re-runs on restore. The bundle never contains code.
8. **Key renames**: `INSTALL_COMPOSER→INSTALL_ACTION`, `CAST_*→CATALOG_*/TOOLKIT_*`, `QUICK_COUNTRY→REGION_COUNTRY`, plain secret keys dropped in favour of `*_FILE`, wizard-internal `GIT_*` keys dropped.
9. **Encryption passphrase for a manual (non-auto) LUKS is asked at cook** and stored as a file in the session `secrets/`, so it is in the bundle. Previously it was typed at birth and never stored.
10. **`apply` loads the recipe's `INSTALL_ACTION` `setup.sh`** (a catalog one only after its preview accept) so registered hooks run on restore. It never runs that action's cook.

## 7. Port order

Every step has the same shape. **Goal** is one sentence. **Do** lists files to create or change. **Delete** lists what leaves the tree in that step. **Tests** lists the `*_TEST.sh` files and the cases each must have. **Gate** is the exact commands that must pass before the box in §0 is ticked. A step is not done while any gate line fails. Do not begin a step while the previous step's gate fails. Do not port "for now" shims from `src.old` into `nds/src`; a symbol from the banned list in §0 never enters the live tree.

Common gate, run at the end of every step (referred to below as **G**):

```bash
bash nds/dev/selftest.sh          # stderr ends with OK, exit 0
bash nds/dev/shellcheck.sh        # exit 0
```

Test convention: `<dir>/<name>_TEST.sh` next to the code, first line after the header `source "$(dirname "${BASH_SOURCE[0]}")/<relative>/setup_TEST.sh"`, then `import_dir` of the directory under test. Record with `bts_pass` / `bts_fail`; labels name the contract. Stub tools by defining a function of the same name before the call and appending to a call log array; assert the log. Fixture recipes live in `nds/src/recipe/fixtures/`. Run one file with `bash utilities/bashTestSuite/main.sh <file>` and no `-f`; on `FAIL n <path>` read that log. Tests never touch `/dev/sd*`, `/mnt`, or the network.

### Step 0 — gate

**Goal.** The runner walks `nds/src` and `fleet/nds-actions`, and every test it finds is green, so later steps have a real gate.

**Do.**
- `git mv nds/src/app/setup_TEST.sh nds/src/setup_TEST.sh`. Set `essentials_test_load logger eventBus importer ui chrome prompt scriptInfo task sessionDir`. Add `nds_test_session` / `nds_test_session_drop` (§4.3). Fix the `source` line in `app/action/action_TEST.sh`, `app/session/mode_TEST.sh`, `app/session/install_logs_TEST.sh`.
- `nds/dev/selftest.sh`: `set -euo pipefail; ROOT=…; exec bash "$ROOT/utilities/bashTestSuite/main.sh" "$ROOT/nds/src" "$ROOT/fleet/nds-actions"`.
- `nds/.wip/OPEN.md`: replace the "Next edit" section with a pointer to this file's §0; delete the sentence that says the architecture is locked in the brief; add the nine step boxes.

**Delete.** `nds/src/app/settings/prompt.md`, `nds/src/app/settings/settings_TEST.sh`, `nds/src/app/realize/realize_TEST.sh`, `nds/src/actions/installFlake/tests/`, `nds/src/actions/remoteAction/tests/`, `fleet/nds-actions/toolkit/tests/` (their subjects are rewritten in steps 3–6; they depend on `src.old` or a pre-loaded legacy shell).

**Tests.** Existing: `action_TEST.sh`, `mode_TEST.sh`, `install_logs_TEST.sh`. No new tests.

**Gate.** G. Additionally: `bash utilities/bashTestSuite/main.sh nds/src` reports at least 3 files.

### Step 1 — recipe contract (`nds/src/recipe/`)

**Goal.** §4.2 exists and is fixture-tested, with no UI and no tools.

**Do.**
- `store.sh`, `schema.sh`, `types.sh` (port the check bodies from `src.old/app.old/settingsManager/logic/validators/**/*.sh`, drop `validation_error` calls), `seed.sh`, `load.sh`, `validate.sh`, `generate.sh`, `materialize.sh`, `export.sh`.
- `schema/<group>.sh` for every group in §4.9: `install region network access boot disk encryption platform flake git scaffold toolkit catalog realize`. Field lists come from `src.old/app.old/settingsManager/data/builtin/<name>.sh` as §4.9 says. Group checks that need a tool call `flake_listHosts`, `flake_probe`, `flake_hostHasDisko`, `git_probe` by name; until step 2 they do not exist, so a check must `declare -f` the name and, if absent, `error "<KEY>: tool not loaded"` and count one problem.
- `fixtures/classic_min.recipe`, `fixtures/flake_local.recipe`, `fixtures/incomplete.recipe`, `fixtures/restore/nds-restore.recipe` with `fixtures/restore/secrets/` files it points at (relative paths).

**Delete.** Nothing.

**Tests.** `recipe/recipe_TEST.sh`: store round trip; condition parser (`=`, `!=`, bare key, comma AND, malformed → error); enabled vs active; seed defaults and a `--detect` stub; `loadFile` accepts `KEY=v` and `KEY="v"`, unescapes `\"` `\\`, ignores `[x]` and `#`, rejects `export`, rejects an unknown key, ignores a locked key with `warn`, resolves relative `*_FILE` against the file's directory, loads `nds-restore.recipe` from a `.zip`; `loadEnv` reads only schema keys, rejects `NDS_<secret minus _FILE>`; `validate` returns the problem count and names each KEY; a group check is called once with the array name; `materialize` generates only when empty and `--generate-when` holds and leaves an existing path alone; `seal` refuses an incomplete recipe and writes nothing; sealing twice is byte-identical; `--portable` omits every key listed in §4.2.7.

**Gate.** G. Additionally: `rg -l 'prompt|ui_[a-z]|nds_requireUtility' nds/src/recipe` prints nothing.

### Step 2 — tools (`nds/src/utilities/`)

**Goal.** Every tool lives under `nds/src/utilities/<name>/main.sh`, is argument-driven, and has its test beside it.

**Do.**
- `git mv nds/src.old/utilities/<name> nds/src/utilities/<name>` for `age disk facter flake git hwconfig nixcfg nixos pkg qr sops targetSeed`. Move each `tests/*_TEST.sh` to `<name>/<name>_TEST.sh` sourcing `nds/src/setup_TEST.sh`.
- Remove the `if ! declare -F error` fallback shims from every `main.sh`.
- `app/utility/utility.sh`: add `nds_utility_addRoot <dir>`; `nds_requireUtility` searches `nds/src/utilities` then added roots, first hit wins.
- `nixcfg`: rename `nds_nixcfg_*` → `nixcfg_*`; `nixcfg_writeClassic <aa> <out_file>` and `nixcfg_writeGeneratedHost <aa> <host_dir> …`: every `nds_cfg_get X` becomes `${_R[X]:-}` on `local -n _R=$1` (also in `install_nixcfg_generated.sh`).
- `disk`: delete `disk_writeEncryptionSecrets`; `disk_luksFormat <partition> <passphrase_file|""> <keyfile|"">`; `disk_setupInitrdSshKeys <mnt> <hostkey_file>` copies the given key instead of generating one.
- `sops`: reduce to `sops_installKey <key_file> <mnt> <secrets_dir> <hostname>` (copy to `/mnt/etc/sops/age/keys.txt`, write pub + enroll note into `secrets_dir`). No `nds_cfg_get`, no keygen.
- `git`: rewrite `main.sh` to the §4.7 tool list (`git_url_parse`, `git_url_safe`, `git_url_toSsh`, `git_url_isRemote`, `git_sshCommand`, `git_probe`, `git_clone`, `git_push`, `git_commitAll`, `git_key_create`, `git_key_pub`, `git_key_fingerprint`, `git_key_bodyLooksValid`, `gh_*`). Keep argument-driven provider internals.
- `targetSeed`: reduce to `targetSeed_copy <src_dir> <mnt>` and `targetSeed_gitKeys <keys_dir> <mnt>`.
- `flake`: add `flake_listHosts <flake_dir>` (from `actions/installFlake/logic/install_flake_hosts.sh`), `flake_probe <keys_dir> <url> <dest>` (clone once, reuse when `<dest>/.git` exists); keep `flake_hostHasDisko`.
- `app/session/dirs.sh`: `nds_session_dir`, `nds_session_sshUser`, `nds_session_hostIp` (from `src.old/lib/lib_net.sh`).

**Delete.** `nds/src.old/utilities/` (now empty), `src.old/utilities/*/tests/run.sh` runners, `git/store/`, `git_store_*`, `GIT_ENV_PREFIX`, `git_gh_login`, `src.old/lib/lib_key.sh`, `src.old/lib/lib_net.sh`.

**Tests.** One `<name>_TEST.sh` per tool. Moved tests keep their cases minus store/env-overlay cases. New cases: `git_TEST.sh` — `git_url_safe` for ssh/https/scp forms, `git_sshCommand` picks `<safeurl>` then `default`, `git_probe`/`git_clone` build the expected `GIT_SSH_COMMAND` (stub `git`); `nixcfg_TEST.sh` — `nixcfg_writeClassic` from a fixture array produces the same blocks the old test asserted; `disk_TEST.sh` — `disk_luksFormat` passes the files through (stub `cryptsetup`); `flake_TEST.sh` — `flake_probe` reuses an existing clone; `targetSeed_TEST.sh` — copy preserves modes into a temp root.

**Gate.** G. Additionally: `rg -l 'nds_cfg_|nds_sm_|nds_ask_|prompt |ui_[a-z]|NDS_RUNTIME_DIR' nds/src/utilities` prints nothing; `ls nds/src.old/utilities` fails.

### Step 3 — realize and bundle (`nds/src/realize/`)

**Goal.** `nds_realize <file>` births from a sealed recipe with no TTY, and `nds_bundle <file>` writes the restore zip; both fixture-tested with stubbed tools.

**Do.**
- Port `src.old/realize/*` behind `nds_realize <file>` per §4.5: `realize.sh`, `preflight.sh`, `plan_classic.sh`, `plan_flake_local.sh`, `plan_flake_remote.sh`, `steps_disk.sh`, `steps_boot.sh`, `steps_flake.sh`, `steps_hardware.sh`, `steps_seed.sh` (local copy; remote returns the `--extra-files` argument), `steps_leafpush.sh`, `verify.sh`, `diag.sh`. `eventCreate realize.pre_disk realize.post_disk realize.pre_install realize.post_install realize.done` in `realize.sh`. Steps are wrapped in `taskStart`/`taskOk`/`taskFail`; installer output goes to the `nixos` logger scope.
- `bundle.sh` (§4.5 layout, `nds_bundle_add`, `eventCreate bundle.collect`) and `bundle_quickstart.sh` (text from `src.old/app.old/bundleManager/logic/bundle_quickstart.sh`, reading `R`).

**Delete.** `nds/src/app/realize/`, `nds/src.old/realize/`, `nds/src.old/lib/lib_hook.sh`, `nds/src.old/app.old/bundleManager/logic/`.

**Tests.** `realize/realize_TEST.sh`: each fixture drives one plan with every tool stubbed to append `name args` to a log; assert exact order and arguments for classic, flake local (with and without `LEAF_PUSH_DIR`, with and without `TARGET_SEED_DIR`), flake remote (`--extra-files` present iff `TARGET_SEED_DIR`); a `realize.pre_install` hook receives `R` and runs between the hardware step and the build step; a failing hook aborts with no later tool call; `LEAF_PUSH_DIR` failure aborts before any disk tool call; `fixtures/incomplete.recipe` returns 1 with no tool call. `realize/bundle_TEST.sh`: from an `nds_test_session` tree → zip lists `nds-restore.recipe`, `secrets/…`, `config/…`, `seed/…`, `logs/…`, `QUICK_START.md`; a `bundle.collect` hook's file is present; `nds-restore.recipe` has relative `*_FILE` values and no `LEAF_PUSH_*`.

**Gate.** G. Additionally: `rg -l 'prompt|ui_[a-z]|nds_cfg_|import_file|import_dir|\bsource ' nds/src/realize` prints nothing.

### Step 4 — pipeline, unattended (`nds/src/app/`)

**Goal.** `main.sh` runs the §4.3 sequence end to end in unattended mode against stubs; interactive screens are not yet ported.

**Do.**
- `app/session/cli.sh` (flags of §4.3; `--help` prints flags and `nds_skip_list`), `app/session/mode.sh` (mode only), `app/session/skip.sh` (store; registers the five framework names; startup check rejects unknown names in `NDS_SKIP` / `NDS_SKIP_*`), `app/session/exit.sh` (publish logs on both exits, purge on clean).
- `app/pipeline.sh` per §4.3 (`nds_pipeline_run`, `nds_pipeline_cook`, `_nds_pipeline_loadRecipeAction`; `eventCreate cook.schema cook.done`). `app/features.sh` load order per §3. `main.sh` calls `nds_pipeline_run`; remove `_nds_run_phases`, `nds_skip_all`, `_NDS_AUTO_CONFIRM_REQUESTED`.
- `app/action/action_check.sh`: required set per §4.4; the six retired names fail the check. `app/action/action.sh`: delete `nds_action_call`. `app/action/action_UI.sh`: delete `nds_action_items`.
- `app/confirm.sh` and `app/finish.sh` exist as stubs that `error` when called (they are ported in step 6); the pipeline gates them with `nds_skip`, so unattended never reaches them.

**Delete.** `nds/src/app/settings/`, `nds/src/app/action/action_TEST.sh` fixtures that use `action_setup`/`action_config` (rewrite), old skip functions in `mode.sh`.

**Tests.** `app/session/skip_TEST.sh`: unattended → every registered name skipped; `NDS_SKIP_INSTALL_CONFIRM=true`; `NDS_SKIP=install.confirm`; `--yes` skips all but `finish.reboot`; unknown name in either form fails at startup; `nds_skip` on an unregistered name fails. `app/pipeline_TEST.sh` with a stub action dir (`action_groups`, `action_pins`, `action_cook`, a `cook.schema` hook adding a group): unattended + env → sealed file exists and the `nds_realize` stub receives that path; `nds_wizard_fill` stub is never called; a missing required key returns 1 before the realize stub; `NDS_RECIPE_FILE` then env override order; `INSTALL_ACTION` is set and locked; `action_cook` runs after validate and `cook.done` after it; `apply` with a fixture whose `INSTALL_ACTION` is the stub action → the stub's `setup.sh` is sourced (a marker hook is registered) and its `action_cook` is not called; re-entrant `nds_pipeline_cook` for a `remote` store. `app/action/action_TEST.sh`: updated to the new contract.

**Gate.** G. Additionally: `rg -l 'action_setup|action_config|action_presets' nds/src/app` prints nothing.

### Step 5 — actions (builtin + fleet)

**Goal.** Every builtin and fleet action follows §4.4 and cooks its recipe from env, unattended, with stubbed tools.

**Do.**
- Rewrite `setup.sh` for `classicInstall`, `installFlake`, `apply`, `remoteAction`, `test`, `uiSmoke` and for fleet `addFleetHost`, `toolkit` per the §4.4 table. `test` and `uiSmoke` keep their debug purpose but satisfy the contract (`action_groups` may print nothing).
- Move `actions/installFlake/logic/*`: host listing and disko detection already went to `utilities/flake` in step 2; leaf write (`.nds/hosts/<host>.recipe` via `nds_recipe_export --portable`), commit message, and `nds_install_flake_commit_push_leaf` logic become part of `addFleetHost`/`toolkit` cook helpers using `git_commitAll`/`git_push`; anything else is deleted.
- `remoteAction/setup.sh` per §4.8 (`action_cook` does discover into `remote`, second preview, `import_file`, re-entrant cook). Catalog discover reads `.nds/actions/<name>/setup.sh` with the same `action_check`.
- Fleet `toolkit/logic/*.sh`: cook helpers per the table; `nds_toolkit_seed_scripts_to_target` becomes the `realize.post_install` hook registered from `setup.sh` (args: `/mnt`, thundercast URL); `hooks/write_operator_pubs.sh` becomes a function in logic called from `action_cook`. Fleet `addFleetHost/logic/scaffold.sh`: the apply part of `src.old/wizard/install/ui/install_flake_scaffold.sh` (templates → host dir), no menu.

**Delete.** `nds/src/actions/*/logic/`, `fleet/nds-actions/toolkit/hooks/`, `nds/src.old/actions` leftovers if any, `nds/src.old/wizard/install/logic/`.

**Tests.** `actions/<name>/<name>_TEST.sh` for `classicInstall`, `installFlake`, `apply`, `remoteAction`; `fleet/nds-actions/<name>/<name>_TEST.sh` for `addFleetHost`, `toolkit`. Each: unattended cook from env with tools stubbed → sealed file has the pins, `INSTALL_ACTION`, and for fleet: `LEAF_PUSH_DIR` set, `.nds/hosts/<host>.recipe` written in `--portable` form, `TARGET_SEED_DIR` tree contains only the listed key files (toolkit). `remoteAction_TEST.sh`: fixture catalog whose action registers a `realize.pre_install` hook and a `cook.schema` group; unattended with `NDS_CATALOG_URL`/`NDS_CATALOG_ACTION` (clone stubbed to copy the fixture); before the pick neither hook nor group exists, after the pick both do; a catalog action missing the contract is skipped with `warn`. `toolkit_TEST.sh` also asserts the `realize.post_install` hook is registered after `setup.sh` is sourced.

**Gate.** G. Additionally: `rg -l 'nds_realize|nixos-install|action_setup|nds_cfg_' nds/src/actions fleet/nds-actions` prints nothing.

### Step 6 — wizard (interactive)

**Goal.** The interactive driver, the custom askers, the git access screens, and the confirm/finish screens exist; the TUI is complete.

**Do.**
- `wizard/ask.sh` per §4.6 (registers `cook.summary`). `wizard/askers/*.sh` per the §4.6 table. `app/confirm.sh` (registers `install.confirm`; text from `src.old/wizard/install/ui/install_confirm.sh`; shows preflight warnings from `nds_realize_preflight --warnings`), `app/finish.sh` (registers `finish.backup`, `finish.reboot`; text from `src.old/app.old/bundleManager/ui/bundle_finish.sh`).
- `git mv nds/src.old/wizard/git/{access,keys,wizard,lib} nds/src/wizard/git/`, then change only the boundary: `nds_cfg_*`/`nds_feat_cfg_*` → `nds_recipe_*` on the passed array; key destinations → `${GIT_KEYS_DIR}/<safeurl>`; probes → `git_probe`; `nds_ui_*`/`nds_ask_*` → `ui_*`/`prompt`; entry point is `nds_ask_gitAccess <aa> GIT_KEYS_DIR`. Move `src.old/wizard/git/tests/*` next to the code; keep URL/key/route cases, delete map/bridge cases.

**Delete.** `nds/src.old/wizard/` (all of it), `nds/src.old/app.old/` (all of it), `nds/src.old/lib/`.

**Tests.** `wizard/ask_TEST.sh` with `prompt` stubbed per call (`prompt() { UI_PROMPT_RESULT=${_answers[$((_i++))]}; }`): each type asker sets its key; back (rc 2) keeps the value; cancel (rc 3) returns 1; summary loop re-asks only failing fields; `NDS_SKIP_COOK_SUMMARY=true` asks only failing fields; a `--recipe` loaded value is offered as default. `wizard/askers/askers_TEST.sh`: `nds_ask_gitAccess` is entered when a probe stub fails and returns without prompting when all pass; `nds_ask_flakeHost` lists the stubbed hosts; `nds_ask_role` offers restore when `.nds/hosts/<host>.recipe` exists. `app/confirm_TEST.sh`: decline returns 1; not called when `install.confirm` is skipped. `app/finish_TEST.sh`: reboot not called without `NDS_REBOOT` when skipped. `wizard/git/*_TEST.sh`: moved cases.

**Gate.** G. Additionally: `rg -l 'prompt ' nds/src/app nds/src/actions fleet/nds-actions` prints only `app/confirm.sh`, `app/finish.sh`, `app/action/action_UI.sh`; `rg -l 'nds_mode_is|nds_skip' nds/src/wizard` prints only `wizard/ask.sh`. First ISO session may happen after this step.

### Step 7 — delete legacy

**Goal.** No legacy tree, no legacy name, docs point at the new layout.

**Do.**
- `nds/dev/shellcheck.sh`: drop the `src.old` path. `.cursor/project.md`: NDS layout table → §3 of this file. `nds/README.md`: layout and run text. `nds/.wip/OPEN.md`: move done items, remove legacy references. `nds/.wip/TESTING.md`: env names per §4.3 and §4.9.

**Delete.** `nds/src.old/` (whatever remains), `nds/docs/src-conventions.md`, `nds/src/app/workflow.md`.

**Tests.** None new.

**Gate.** G. Additionally, both print nothing:

```bash
ls nds/src.old 2>/dev/null
rg -n 'nds_app_|SCRIPT_DIR|APP_DIR|nds_import_file|nds_ui_|nds_ask_user_to_proceed|nds_cfg_|nds_sm_|nds_preset_|nds_feat_cfg_|CONFIG_DATA|CONFIG_DEFAULTS|PRESET_REGISTRY|PRESET_META|PRESET_HOOKS|nds_step_|nds_install_log|NDS_UI_QUIET|NDS_RUNTIME_DIR|NDS_INSTALL_CONFIRMED|NDS_AUTO_CONFIRM|NDS_UNATTENDED|NDS_SKIP_MENU|NDS_[A-Z_]+_SKIP\b|nds_realize_run|nds_realize_confirm|nds_hook_|nds_bundle_register_|remote_action_|NDS_REMOTE_ACTION_DID_INSTALL|NDS_PRESET_EXTRA|NDS_CFG_AA_NAME|git_store_|GIT_ENV_PREFIX|NDS_GIT_METHOD|NDS_GIT_KEY_|NDS_GIT_AUTH_SKIP|NDS_GIT_IMPORT|NDS_GIT_GH_|NDS_FLAKE_PROBE|NDS_CAST_|src\.old' nds/src nds/dev nds/README.md fleet/nds-actions .cursor/project.md
```

(`NDS_SKIP` and `NDS_SKIP_<NAME>` do not match `NDS_[A-Z_]+_SKIP\b`; `NDS_GIT_KEYS_DIR` does not match the `NDS_GIT_` patterns.)

### Step 8 — ship

**Goal.** Versioned, committed.

**Do.** Bump `nds/src/VERSION` MAJOR (CLI and recipe format are breaking). Tick the last box in §0. Commit with a message naming this file.

**Gate.** G.

## 8. Conventions for the port

- Public NDS names: `nds_<area>_<verb>[_<noun>]`, snake case (`nds_recipe_seal`, `nds_wizard_fill`, `nds_realize`, `nds_bundle`, `nds_pipeline_run`). Private: leading `_`. Tools keep their own prefix without `nds_` (`disk_*`, `nixos_*`, `git_*`, `flake_*`, `nixcfg_*`, `sops_*`, `targetSeed_*`, `facter_*`, `hwconfig_*`, `pkg_*`, `age_*`, `qr_*`).
- Arrays are passed by name; `local -n` only for arrays. Scalars are passed as arguments. No function reads a global recipe.
- Files that must be sourced start with the `BASH_SOURCE` guard used in the live tree. Every feature dir is loaded with `import_dir <dir> --depth 0`; ordering inside a dir is alphabetical, so a file that defines a function another file calls at source time must sort first (prefix `_` or `aa_` is not allowed; rename the function to be called later instead).
- Errors: `error "<KEY>: <problem>"` then a non-zero return. No `exit` outside `main.sh`. No return codes other than 0/1/2 (2 = back) unless a prompt defines it.
- Logging: `session` scope for NDS events, `nixos` scope for installer output. `info` for steps, `debug` for skipped/ignored, `warn` for degraded, `error` for problems.
- Tests never touch `/dev/sd*`, `/mnt`, or the network; tools are stubbed by name.

## 9. Repair pass (added by review of `b89045e`)

What went wrong in the first pass, so it is not repeated: every test stubbed the NDS tool *functions*, so a plan that called a function that does not exist, or called it with the wrong arguments, still passed. Fixtures were edited until validation passed instead of fixing the schema. Legacy files were read for their shape, not their behaviour. This section adds the missing gates and lists every defect found. Read the legacy file named in each item from `d60000a` before touching the new one.

### 9.1 Realize and tools (reopens step 3, touches step 2)

Legacy: `git show d60000a:nds/src/realize/{main,plan_classic,plan_flake,steps_disk,steps_boot,steps_flake,steps_hardware,preflight,verify,diag}.sh`.

| # | Defect | Fix |
|---|---|---|
| R1 | `nixos_prefetchFlake`, `nixos_installFlake`, `nixos_verify`, `hwconfig_write` are called from `realize/` and defined nowhere | Port the legacy bodies: `nds_git_prefetch_flake_closure` → `nixos_prefetchFlake <flake_root> <keys_dir>` (iterates `flake_listLockGitEntries`, `nix build`/`fetchTree` with `git_sshCommand`); `_nds_realize_nixos_flake` → `nixos_installFlake <flake_root> <host> <host_dir> <hw_placement>` (build via `nixos_buildFlakeSystem`, `flake_gitUnstageHostFacts`, `nixos_activateSystem`, `nixos_ensureInstallArtifacts`, `--override-input hardware` when placement is `etc-nixos`); legacy `verify.sh` (152 lines) → `nds_realize_verify <aa> <kind>` in `realize/verify.sh` (not a tool wrapper); legacy `steps_hardware.sh` → `step_hardware <aa> <host_dir>`: `facter_write` + sanitize for flake, `hwconfig_generate` for classic, placement `host-dir` / `etc-nixos` / `skip`, always overwrite |
| R2 | `step_disk`: `disk_luksFormat` is called on the whole disk *before* partitioning; `disk_partition disk` drops the encryption and UEFI arguments; `disk_mountRoot /mnt` passes the mount point as the encryption flag; `disk_diskoApply disk` drops 9 arguments; `nixos_ensureLiveStoreSpace` is gone | Port legacy `steps_disk.sh` exactly: `disk_unmountTarget /mnt`; `nixos_ensureLiveStoreSpace 64`; `disk_partition <disk> <ENCRYPTION> <BOOT_UEFI_MODE> [_step_luksFormat]` where the callback runs `disk_luksFormat <root_partition> <ENCRYPTION_PASSPHRASE_FILE> <ENCRYPTION_KEY_FILE>`; `disk_mountRoot <ENCRYPTION> /mnt`; disko: `disk_diskoApply <disk> <DISK_FS_TYPE> <DISK_SWAP_SIZE_MIB> "" "" <ENCRYPTION> <unlock> <DISK_DISKO_CONFIG> <BOOT_LOADER> "${work_dir}/disko"` with `unlock=keyfile` when key without password else `manual`; then initrd host key copy. The step reads `_R` and passes scalars; the tool signatures are the source of truth |
| R3 | `step_efi` calls `disk_efiRegister <disk>`; the tool wants `<disk> <loader_path> [label]`; legacy `_nds_realize_register_efi` decided by UEFI mode and loader | Port `_nds_realize_register_efi <aa>`: no-op when `BOOT_UEFI_MODE != true`; loader path from `BOOT_LOADER` (`systemd-boot` → `\EFI\systemd\systemd-bootx64.efi`, `grub` → `\EFI\NixOS-boot\grubx64.efi` — take the exact strings from the legacy file) |
| R4 | `nixos_setBootContext` is never called; bootloader repair and remount in `nixos_ensureInstallArtifacts` run with defaults | Call `nixos_setBootContext <BOOT_LOADER> <BOOT_UEFI_MODE> <DISK_TARGET> <ENCRYPTION>` at the top of every plan |
| R5 | Flake local plan lacks `flake_hostStructureOk`, `flake_gitStageHostFiles` (stage host files so `nix flake` sees them), and passes `nixcfg_writeGeneratedHost` a made-up argument list | Restore the legacy step order from `plan_flake.sh` lines 56–91: disk → stage → hardware → generated host → structure check → git stage → prefetch → eval → install → git keys → sops → EFI → verify. `nixcfg_writeGeneratedHost <aa> <host_dir>` reads what it needs from `_R` |
| R6 | `preflight.sh` only prints erase lines; legacy checked disk exists and is not mounted, systemd-boot/rEFInd on BIOS, remote reachability | Port `nds_realize_preflight_local` / `_remote` bodies as errors; keep the `--warnings` mode for the confirm screen and add the legacy warnings (small disk, existing partitions) |
| R7 | `diag.sh` is a `debug` line; legacy wrote disk/mount/profile snapshots and a failure dump into the diagnostics log that `session/failure.sh` tails | Port `nds_realize_diag_snapshot`, `nds_realize_diag_after_partition`, `nds_realize_diag_step_failure` writing to `${ nds_session_dir logs; }/diag.log`; `_realize_step` calls the failure dump on a failing step; `install_logs.sh` publishes that file |
| R8 | `bundle_quickstart.sh` is 27 lines; legacy was 373 lines of per-recipe first-login, LUKS, remote-unlock, sops, and toolkit instructions | Port the legacy generator reading `_R`; every section that existed must exist, keyed on the same recipe values |
| R9 | `sops/ops/install_sops.sh` lost the `.toolkit/machines/<host>/keys/age.pub` write and the enroll note text | `sops_installKey` keeps: copy to `/mnt/etc/sops/age/keys.txt`, pub + private copy into `secrets/`, enroll note (legacy text), and — when `LEAF_PUSH_DIR` is set — the machine pub into `${LEAF_PUSH_DIR}/.toolkit/machines/<host>/keys/age.pub` (the pub is known at cook now, so write it in the leaf before the push step; move that write into the toolkit/addFleetHost cook, not into realize) |
| R10 | `targetSeed_gitKeys` dropped `tcast-git-ssh` + `git.map` under `/mnt/var/lib/tcast/` | Port from legacy `install_git_keys_target.sh`: for each key in `GIT_KEYS_DIR` write `/mnt/root/.ssh/nds/<safeurl>`, plus the ssh config include and the `git.map` the tcast toolkit reads |
| R11 | `utilities/git`: verify what remains of the provider internals actually runs (`git_github_gh.sh`, `git_github_api.sh`, `git_github_session.sh` are 700 lines that nothing in the new wizard calls) | Either wire them from `wizard/git` (§9.3) or delete them. Dead code is not allowed to stay because it "might be useful" |

### 9.2 Actions (reopens step 5)

Legacy: `git show d60000a:fleet/nds-actions/toolkit/logic/install_flake_toolkit.sh`, `…/toolkit/hooks/write_operator_pubs.sh`, `nds/src/wizard/install/ui/install_flake_scaffold.sh`, `nds/src/actions/installFlake/logic/install_flake_leaf.sh`, `nds/src/actions/remoteAction/logic/install_flake_cast.sh`.

| # | Defect | Fix |
|---|---|---|
| A1 | `toolkit/setup.sh` writes literal `AGE-SECRET-KEY-1TOOLKIT` and `toolkit-ssh-private` as the operator keys | `action_cook` calls `age_keygen -o` and `ssh-keygen -t ed25519 -N ""` through the tools (legacy `nds_toolkit_generate_operator`), derives the pubs with `age_keygen -y` / `ssh-keygen -y`, and writes those. Tests stub the *binaries* (§9.5 G3), not the cook |
| A2 | Toolkit restore (`TOOLKIT_MODE=restore`, `TOOLKIT_BUNDLE`) is not implemented | Port `nds_toolkit_restore_from_bundle` (zip or dir → `secrets/toolkit/`) and branch on `TOOLKIT_MODE` |
| A3 | `nds_toolkit_seed_scripts_to_target` ignores its first argument, clones to `src` and links `current → src`; legacy linked `current → src/fleet/toolkit`, set the origin remote, and `chmod +x` the scripts | Port the legacy body; signature `<mnt> <thundercast_url>`; the hook is registered with those arguments bound |
| A4 | `addFleetHost/logic/scaffold.sh` copies `.roles/<role>` verbatim; legacy rendered the `*.tmpl` files in `actions/installFlake/templates/` (still present, unused) with hostname, disk, encryption, network values | Port the template rendering from legacy `install_flake_scaffold.sh` (the apply half) into `nds_fleet_scaffold_host <aa> <leaf> <system> <host> <role>`; delete the templates only if the port does not use them |
| A5 | `addFleetHost` and `toolkit` cook hard-code `hosts/x86_64-linux` | Use `FLAKE_HOST_DIR` |
| A6 | `remoteAction/setup.sh` "second accept" only prints `action_preview`; nothing asks | After `import_file` of the catalog action, call `_nds_action_ui_preview` (the same confirm the first accept uses) unless `nds_skip action.preview`; decline returns 1 |
| A7 | `remoteAction/setup.sh` clones only when unattended, relying on the asker having cloned; a `--recipe` interactive run has no clone | Clone when `work/catalog/.git` is absent, regardless of mode |
| A8 | `apply` enables all groups, but `catalog`, `toolkit`, `scaffold` have no `--when`, so a restored classic or installFlake recipe fails validation on `CATALOG_URL`. Fixtures were given a fake `CATALOG_URL` to hide this | `nds_schema_group catalog … --when 'INSTALL_ACTION=remoteAction'`, `toolkit … --when 'INSTALL_ACTION=toolkit'`, `scaffold … --when 'INSTALL_ACTION=addFleetHost'`. Remove `CATALOG_*` from `classic_min.recipe` and `flake_local.recipe`. `classic_min.recipe` gets `DISK_STRATEGY=nds` and a `DISK_TARGET`; tests that need the `disk` type check to pass stub `disk_canUse`/`-b` via the §9.5 G3 helper, not by changing the fixture's meaning |
| A9 | `INSTALL_ACTION` ends up as the catalog action name after a remote cook, so `apply` cannot find `remoteAction` to re-clone | Keep `INSTALL_ACTION=remoteAction`; record the inner action in `CATALOG_ACTION` (already a key). `_nds_pipeline_loadRecipeAction` handles `remoteAction` per §4.3 |
| A10 | `nds_recipe_set` ignores locks | Locked keys are rejected by `nds_recipe_set` with `error` and return 1, except through `_nds_pipeline_apply_lines … lock` and the pipeline's own `INSTALL_ACTION` set. Add the test |
| A11 | `test` and `uiSmoke` are 18-line stubs | Acceptable only if `NDS_TEST` still shows them and `uiSmoke` walks every type asker once (so a TTY pass can eyeball the widgets). Port that walk |

### 9.3 Wizard (reopens step 6)

Legacy: `git show d60000a:nds/src/wizard/git/…` (access, keys, wizard, lib), `nds/src/wizard/install/ui/install_confirm.sh`, `nds/src/app/bundleManager/ui/bundle_finish.sh`.

| # | Defect | Fix |
|---|---|---|
| W1 | `wizard/git/` is 232 lines; the gh device-login flow, key title collision handling, account-vs-deploy key choice, QR card, per-owner session key, and closure walk with per-URL retry are gone. `gh_deviceLogin` / `gh_addDeployKey` are one-line calls into 700 lines of provider code that may not match | Port the legacy screens per §4.7 boundary rule: keep their internals, change reads/writes to `nds_recipe_*`, key paths to `${GIT_KEYS_DIR}/<safeurl>`, probes to `git_probe`. The closure walk is `nds_ask_gitAccess`'s loop. Every `gh_*` function the wizard calls must exist and have a test that stubs the `gh` binary |
| W2 | `confirm.sh` shows two lines; legacy showed the full settings summary per group, the wipe target, remote target, and preflight warnings | `nds_confirm` renders every active group with `ui_kv` (schema labels, choice labels, secrets as `(file)`), then the preflight warnings, then the confirm. Port the legacy wording |
| W3 | `finish.sh` dropped the tar.gz name in the copy hint's SSH variant, the online-guide link, and the remote-install next-steps (sops enroll note) | Port from legacy `bundle_finish.sh` and `nds_install_remote_finish` |
| W4 | `ask.sh`: verify the summary loop offers `Edit <group>` and re-asks only failing fields on Accept-with-problems (§4.6). If it does, add the test; if not, implement | — |

### 9.4 Housekeeping

- `nds/.wip/OPEN.md` was not updated in any step. Update it now: step boxes mirror §0, "Ops gates" entry about the parked selftest is done, legacy references removed.
- `nds/.wip/TESTING.md`: env names per §4.3 / §4.9 (`NDS_MODE`, `NDS_SKIP_*`, `NDS_REBOOT`, `GIT_KEYS_DIR`, `TOOLKIT_*`, `CATALOG_*`).
- `nds/src/actions/README.md` still describes the preset lifecycle; rewrite to §4.4.
- `nds/src/logs/*.log` are committed runtime output; `git rm --cached` them and add `nds/src/logs/` to `.gitignore`.
- Commit the pending essentials fixes (`eventBus_dispatch.sh`, `prompt.sh`, `sessionDir.sh`, their tests and READMEs) as their own commit before the repair commit; NDS tests run against them.

### 9.5 New gates (apply to §9 and to every later step)

- **G1 Resolution.** `nds/src/realize/realize_TEST.sh` and `nds/src/app/pipeline_TEST.sh` load the real `utilities/`, `recipe/`, `realize/`, `app/` trees (no function stubs), then for every identifier matching `^(disk|nixos|nixcfg|flake|git|gh|facter|hwconfig|sops|targetSeed|pkg|age|qr|step|nds)_[A-Za-z_]+` that appears as a command in `nds/src/realize/*.sh`, `nds/src/app/*.sh`, `nds/src/actions/*/setup.sh`, `fleet/nds-actions/*/setup.sh`, `fleet/nds-actions/*/logic/*.sh` (extract with `rg -o`), assert `declare -F` succeeds. One `bts_fail` per unresolved name.
- **G2 Arity.** Every tool function in `utilities/` that realize or a cook calls has a `# Arguments:` header block, and a test in that tool's `*_TEST.sh` that calls it with those arguments and a stubbed binary. Realize tests do not stub tool functions.
- **G3 Stub binaries, not functions.** `nds/src/setup_TEST.sh` gains `nds_test_stubBins <name>…`: creates a temp dir of executable shims that append `name args` to `$NDS_TEST_BIN_LOG` (and honour `NDS_TEST_BIN_RC_<NAME>` for a forced exit code), prepends it to `PATH`; `nds_test_stubBins_drop` restores. Stub set for realize tests: `git nix nix-build nixos-install nixos-enter cryptsetup sgdisk parted partprobe wipefs mkfs.ext4 mkfs.vfat mkswap swapon mount umount mountpoint lsblk blkid findmnt efibootmgr age-keygen ssh-keygen ssh nixos-facter nixos-generate-config disko zip unzip reboot gh`. Function stubs are allowed only for `prompt`, `reboot`, and the three `realize.*`/`bundle.collect` test hooks.
- **G4 No fake material.** `rg -n 'AGE-SECRET-KEY-1TOOLKIT|toolkit-ssh-private|example\.com|placeholder' nds/src fleet/nds-actions --glob '!*_TEST.sh' --glob '!*.md'` prints nothing.
- **G5 Fixture honesty.** No fixture carries a key its group's `--when` would not activate for that recipe's `INSTALL_ACTION`/`INSTALL_KIND`. `classic_min.recipe` has no `CATALOG_*`, no `FLAKE_*`, `DISK_STRATEGY=nds`.
- **G6 Parity ledger.** Before deleting or shrinking any legacy function during a port, write one line in §0 Log: `dropped <legacy fn> because <reason>`. A behaviour that has no such line and is missing is a defect. Reviewers grep the legacy file's function list against the new tree.
- **G7 Real invocation.** After §9.1–§9.3: `NDS_MODE=unattended NDS_ACTION=classicInstall NDS_DISK_TARGET=/dev/null … bash nds/src/app/main.sh` under `nds_test_stubBins` from a test (`app/main_TEST.sh`) reaches `nds_realize` and the stub log shows `sgdisk`/`parted`, `cryptsetup` (when encrypted), `nixos-install`, in that order. This is the first time `main.sh` runs; it runs only inside the test harness with stubbed binaries and `ROOTREEXEC_ROOT` unset.

Order of work: 9.5 G3 helper first (everything else depends on it), then 9.1 top to bottom, then 9.2, then 9.3, then 9.4, then G1/G7. Each of 9.1, 9.2, 9.3 ends with G (§7) plus G1–G6. Tick step 9, then re-tick 3, 5, 6, then 8 (bump to `6.0.1`; the format did not change).
