# Handoff: cook as a phase runner (6.1)

Read this file, `.cursor/project.md`, `utilities/bashTestSuite/README.md`. Edit only §2 Status here. Do not re-read `REFACTOR-PLAN.md` or `HANDOFF-NOTES.md` for the live tree — both are stale. There is no `nds/src/realize/`, no `app/realize/`, no `app/settings/`, no `installFlake/logic/`. If an index lists them, `find` on disk wins.

6.0.1 closed: session **U** installed a machine. Self-test was green after that pass. Loop tier stays parked.

## 1. Guardrails

Still in force from 6.0.1. A change that breaks one is wrong even if tests pass.

- Pipeline: discover → select → fill recipe → materialize → seal → confirm → `nds_cook <file>` → bundle → finish. Events hook *into* that sequence. They are not the sequence.
- Recipe is a flat associative array passed **by name**. Fill owns `_NDS_RECIPE`. Cook loads its own `local -A R` from the sealed file and reads nothing else.
- Schema (`recipe/schema/*.sh`) is the only key table. Type checks are value shape. Machine-state checks are preflight.
- Secrets are `*_FILE` paths. Cook never generates secrets.
- Tools take arguments and do one job. They never prompt, never read the recipe array.
- `prompt` lives in `wizard/` only. Unattended never enters `wizard/`.
- Runtime flags are exactly: `NDS_MODE`, `NDS_SKIP` / `NDS_SKIP_<NAME>`, `NDS_YES`, `NDS_REBOOT`, `NDS_ACTION`, `NDS_RECIPE_FILE`, `NDS_FLEET_ACTIONS_DIR`, `NDS_TEST`. Every other `NDS_<KEY>` is a schema key. Do not add a flag. `_NDS_TARGET_ROOT` is internal (default `/mnt`, test session sets it).
- Actions fill recipes. They do not partition and do not call `nixos-install`. Birth lives in `cook/`.
- Target *data* goes through `TARGET_SEED_DIR` (local copy, remote `--extra-files`). Target *code* is a cook hook registered from that action's `setup.sh`. `apply` re-sources that `setup.sh`. Prefer seed files over hooks when the effect is a file. Do not invent a new event.
- No `NDS_TEST_` in product code. No tool-function stubs (binaries via `nds_test_stubBins`). No placeholder key material. No Python. Do not amend old commits. Do not edit `.cursor/rules`. Production `ROOTREEXEC_ROOT` stays `true`.

## 2. Status

Resume: first unchecked task, its gate, tick, Log line, mirror into `nds/.wip/OPEN.md`.

- [x] T1 cook is one phase runner; delete the three plan files
- [x] T2 leftover bugs from U / the review
- [x] T3 docs and VERSION
- [x] T4 architecture page (last)

**Log**

- 2026-09-29: session U passed on a BIOS VM (hostname `host`, vfat `/boot` on `sda2`, NixOS 26.05). Phase runner is unblocked.
- 2026-09-29: T1. `nds_cook` is the phase runner. `plan_classic.sh`, `plan_flake_local.sh`, and `plan_flake_remote.sh` are gone. `step_efi` is `step_bootloader`. G0, G1, G3 passed.
- 2026-09-29: T2. Dropped the hardcoded `umount -R /mnt`. NDS no longer sets `CHROME_HOLD`. Confirm flake path uses `_NDS_TARGET_ROOT`. Session U was already signed off. G0 passed.
- 2026-09-29: T3. VERSION `6.1.0`. Project map cook line is the phase runner. G0 passed.
- 2026-09-29: T4. `nds/docs/architecture.md` is the design page. `REFACTOR-PLAN.md` and `HANDOFF-NOTES.md` are deleted. This file stays. G0 passed.

## 3. Locked design

Cook is one function. It does not pick a meal script. Each phase reads `R` and runs or skips, same idea as schema `--when`. `INSTALL_KIND` and `INSTALL_MODE` choose **tools**, not files.

Delete `plan_classic.sh`, `plan_flake_local.sh`, `plan_flake_remote.sh`. Do not move those sequences into action `setup.sh` files. `apply` must keep working from a sealed file plus a re-sourced `setup.sh` for hooks only.

After load / validate / preflight, `nds_cook` runs this order. Wrap every tool step in `_cook_step` (keep `taskSpin` / `taskOk` / `taskFail`). Unknown `INSTALL_KIND` is an error.

1. `nixos_setBootContext` from `BOOT_LOADER`, `BOOT_UEFI_MODE`, `DISK_TARGET`, `ENCRYPTION`
2. `eventRun cook.pre_disk`
3. `LEAF_PUSH_DIR` set → `step_leafPush`
4. `INSTALL_MODE` is not `remote` → `step_disk` (it already branches on `DISK_STRATEGY` / `ENCRYPTION`)
5. `eventRun cook.post_disk`
6. Config, by keys:
   - `INSTALL_KIND=classic` → `nixcfg_writeClassic`, `step_hardware`, `nixos_copyConfigs`
   - `INSTALL_KIND=flake` → `step_stageFlake`; if local also `step_hardware`, `nixcfg_writeGeneratedHost`, `flake_hostStructureOk`, `flake_gitStageHostFiles`; then `nixos_prefetchFlake`, `nixos_flakeEval`
7. `eventRun cook.pre_install`
8. Install tool:
   - classic → `nixos_installClassic`
   - flake + local → `nixos_installFlake`
   - flake + remote → `nixos_anywhere` (seed via `step_seedRemoteArgs`, plus `--key-file` when `ENCRYPTION_KEY_FILE` is set)
9. After install, if `INSTALL_MODE` is local:
   - `TARGET_SEED_DIR` set → `step_seed`
   - `GIT_PERSIST_ACCESS=true` and `GIT_KEYS_DIR` set → `step_seedGit`
   - `SOPS_AGE_KEY_FILE` set → `sops_installKey`
10. `eventRun cook.post_install`
11. Local → `step_bootloader` (replaces `step_efi`)
12. Local → `nds_cook_verify` (`classic` or `flake`)
13. `eventRun cook.done`

`step_bootloader`: one file `steps_boot.sh` (keep the path), function `step_bootloader`. UEFI → `disk_efiRegister` as today. BIOS → no-op here (`nixos-install` already wrote GRUB; verify still checks `grub.cfg` / `disk_grubBiosBootOk`). Delete `step_efi`.

Events stay exactly: `cook.pre_disk`, `cook.post_disk`, `cook.pre_install`, `cook.post_install`, `cook.done`. Toolkit's `cook.post_install` hook stays. Do not convert it to a seed in this pass.

## 4. Tasks

### T1 — phase runner

- Rewrite `nds/src/cook/cook.sh` as the runner above. Keep `_cook_step`, `_nds_cook_unlock`, `_NDS_TARGET_ROOT`.
- `git rm` the three `plan_*.sh` files.
- Rename `step_efi` → `step_bootloader` in `steps_boot.sh`. Update the one caller (now `cook.sh`).
- `cook_TEST.sh`: keep every current assertion (classic partition+install, encrypted `luksFormat`, flake local build, leaf push before disk, seed copy, remote `--extra-files`, `pre_install` before build, failing hook / failing leaf abort). Rename the "Plans" section if you want. Add one case: classic fixture + `TARGET_SEED_DIR` copies the seed (proves seed is not flake-only).
- Grep in product code (exclude this file, `REFACTOR-PLAN.md`, `HANDOFF-NOTES.md`) for `nds_cook_plan_`, `step_efi`, `plan_classic`, `plan_flake` must be empty.

**Gate.** §5 G0 + G1 + G3. `cook_TEST.sh` still covers the cases above.

### T2 — leftover bugs

| # | Fix |
|---|---|
| B1 | `disk_partition` line `umount -R /mnt` — delete it. Caller already ran `disk_unmountTarget "$_NDS_TARGET_ROOT"`. A tool does not hardcode `/mnt`. |
| B2 | `NDS_CHROME_HOLD` is not a runtime flag. Session U used it for a visual pass that is done. Remove `[CHROME_HOLD]="${NDS_CHROME_HOLD:-false}"` from `app/main.sh`. Remove `export NDS_CHROME_HOLD=true` from `nds/.wip/TESTING.md` session U. Essentials `CHROME_HOLD` stays; NDS just does not set it. |
| B3 | `app/pipeline/confirm.sh`: `FLAKE_INSTALL_PATH` fallback is `"${_NDS_TARGET_ROOT:-/mnt}/etc/nixos"`, not a `/mnt` literal. Operator text that *says* `/mnt` on a real ISO may stay. |
| B4 | `nds/.wip/TESTING.md` sign-off row **U** is `done` (the U section already says so). Header line "none signed off" / "every row is open" must not contradict that. Do not mark A–E done. |

**Gate.** §5 G0. `rg -n 'umount -R /mnt' nds/src` prints nothing. `rg -n 'NDS_CHROME_HOLD' nds/src nds/.wip/TESTING.md` prints nothing.

### T3 — VERSION and pointers

- `nds/src/VERSION` → `6.1.0`
- `.cursor/project.md` cook line: birth is a phase runner, no `plan_*.sh`
- `nds/README.md` Tests / version if they still say 6.0.1
- `nds/.wip/OPEN.md`: mirror these boxes

**Gate.** §5 G0. File contents match 6.1.0.

### T4 — architecture (last, after T1–T3 are ticked)

- Create `nds/docs/architecture.md` from §1 plus the T1 phase list and the T4 name table in the *old* handoff (recipe = fill, cook = birth). Under 120 lines.
- `git rm` `nds/src/REFACTOR-PLAN.md` and `nds/src/HANDOFF-NOTES.md`.
- Point `nds/.wip/OPEN.md` and `.cursor/project.md` at `nds/docs/architecture.md`.
- Do **not** delete this file.

**Gate.** §5 G0. Architecture file exists. The two deleted files are gone.

## 5. Gates

From repo root, Bash 5.3.

- **G0** (every task): `bash nds/dev/selftest.sh` → stderr `OK`, exit 0. `bash nds/dev/shellcheck.sh` → exit 0.
- **G1**: `cook_TEST.sh` / `pipeline_TEST.sh` still resolve every `^(disk|nixos|nixcfg|flake|git|gh|facter|hwconfig|sops|targetSeed|pkg|age|qr|step|nds)_[A-Za-z_]+` name from `nds/src/cook/*.sh`, `nds/src/app/**/*.sh`, `nds/src/actions/*/setup.sh`, `fleet/nds-actions/*/setup.sh`, `fleet/nds-actions/*/logic/*.sh`.
- **G3**: no `^(disk|nixos|nixcfg|flake|git|gh|sops|targetSeed|hwconfig|facter|age|pkg|qr)_[A-Za-z]+\(\)` stubs in `cook_TEST.sh`, `pipeline_TEST.sh`, `main_TEST.sh`.

Report back: ticks, Log lines, `VERSION`, whether G0 was run.

## 6. Do not

- Do not run `sudo bash nds/dev/looptest.sh` or "fix" the loop tier.
- Do not start essentials console-writer work (`nds/.wip/OPEN.md` item A).
- Do not put birth steps in `actions/*/setup.sh`.
- Do not add cook events.
- Do not comment out `ROOTREEXEC_ROOT`.
- Do not run `nds/src/app/main.sh` outside the harness.
- Do not add `NDS_CHROME_HOLD` or any other flag.
- Do not keep `nds_cook_plan_*` as wrappers around the new runner.
- Do not mark T4 done because the architecture file is a stub.

## Pointers

- Pasteable implementer prompt: `nds/src/cook/prompt.md`
- Current runner to replace: `nds/src/cook/cook.sh` (the `case INSTALL_KIND/INSTALL_MODE` is the defect)
- Step bodies to keep: `nds/src/cook/steps_*.sh`, `preflight.sh`, `verify.sh`, `bundle.sh`
- Tests: `nds/src/cook/cook_TEST.sh`, `nds/src/setup_TEST.sh`, `utilities/bashTestSuite/README.md`
- Session U notes: `nds/.wip/TESTING.md` section U (status done)
- Toolkit hook you must not break: `fleet/nds-actions/toolkit/setup.sh` `cook.post_install`
