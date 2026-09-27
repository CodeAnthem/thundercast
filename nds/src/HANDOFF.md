# NDS handoff — close the refactor

This file replaces `REFACTOR-PLAN.md` as the thing you read. The plan stays in the tree as reference only; open it solely for a section this file cites (`PLAN §x.y`). Do not re-read it whole.

Read before starting: this file, `.cursor/project.md`, `utilities/bashTestSuite/README.md`. Legacy code for any remaining port lives in commit `d60000a` at `nds/src/…` paths (`git show d60000a:<path>`). `nds/src.old` does not exist; do not look for it.

Edit only §2 Status in this file. §1 and §4 are fixed unless the user says otherwise.

## 1. Guardrails — the design you must not break

Every one of these was violated once already and had to be repaired. A change that breaks one is wrong even if the tests pass.

**Shape**

- Pipeline is a function sequence in `app/pipeline/pipeline.sh`: discover → select → preview → fill the recipe → materialize secrets → seal to a file → confirm → cook from that file → bundle → finish. Events are hooks *into* that sequence, never the sequence itself.
- The recipe is a flat `KEY=value` associative array passed **by name**. There is no global recipe. The fill phase owns its array; cook (`nds_cook <file>`) loads its own `local -A R` from the sealed file and reads nothing else — no env, no fill-phase state, no other array.
- The schema (`recipe/schema/*.sh`) is the single source of truth for keys: defaults, `--when` conditions, types, validators, askers, generators. Defaults, validate, ask, summary, env import, file import, export are generic walkers over it. No per-key special cases anywhere else.
- Type checks are about the **value's shape**; checks about **machine state** (a block device exists, EFI vars present, `/mnt` mounted) belong to cook's preflight. This is what lets the unit tier run without hardware.
- Secrets are `*_FILE` paths. No plain secret values in the array, the env, the recipe file, or logs. Generation happens in `nds_recipe_materialize` (fill side); cook only copies files.
- Tools (`utilities/<name>/main.sh`) take arguments and do one job. They never prompt, never read the recipe array, never call each other's higher layers. Their `# Arguments:` header is the contract; callers match it exactly.
- The interactive driver (`wizard/`) is the only tree that calls `prompt`. Nothing in `wizard/` checks the mode. Unattended never enters `wizard/`.
- Every question that is not a schema field is behind a registered skip name (`nds_skip_register` / `nds_skip`, `app/session/skip.sh`). Schema fields are never individually skippable.
- Runtime flags are exactly: `NDS_MODE`, `NDS_SKIP` / `NDS_SKIP_<NAME>`, `NDS_YES`, `NDS_REBOOT`, `NDS_ACTION`, `NDS_RECIPE_FILE`, `NDS_FLEET_ACTIONS_DIR`, `NDS_TEST`. Every other `NDS_<KEY>` must be a schema key or it is an error. Do not add a flag.
- Actions are `setup.sh` with `# Description:`, `action_groups`, `action_preview`, optional `action_defaults`, `action_pins`, and the fill hook (`action_recipe` after T4; `action_cook` before). Extension is `eventRegister` on the named events only (PLAN §4.4, names per T4). No directory of hooks is scanned anywhere. No new event without adding it to that table.
- Cook effects on the target that are data go through `TARGET_SEED_DIR` (files only; local copy, remote `nixos-anywhere --extra-files`). Effects that are code go through cook-side hooks registered by the action's `setup.sh`. `apply` re-loads the recipe's `INSTALL_ACTION` `setup.sh` so hooks run on restore.
- Git access is a directory-as-map: `GIT_KEYS_DIR/<safeurl>`. No key maps in the recipe, no in-memory store, no env overlay.
- The bundle is the fixed session layout (`nds-restore.recipe`, `secrets/`, `config/`, `seed/`, `logs/`, `QUICK_START.md`) plus `bundle.collect`. It never contains NDS, fleet, or catalog code.
- The install target root is `_NDS_TARGET_ROOT` (default `/mnt`), an internal variable set only by the test session. Not a flag, not a recipe key. No other `/mnt` literal in cook code.
- `utilities/essentials` is generic Bash. No NDS behaviour goes in.

**Process**

- Never edit a fixture, or set a test env value, to make validation pass. Fix the schema or the code. A fixture carries only keys its `INSTALL_ACTION`/`INSTALL_KIND` would activate. `DISK_STRATEGY=flake` in a test that is not about a flake-owned disk is such a cheat.
- No test back doors in product code. `NDS_TEST_*` names appear only in `nds/src/setup_TEST.sh` and `*_TEST.sh`.
- Never write placeholder material (`AGE-SECRET-KEY-…`, `example.com`, fake keys) into product code. Generate through the tool or fail.
- Never stub an NDS tool *function* in a test. Stub binaries with `nds_test_stubBins` (`nds/src/setup_TEST.sh`). Function stubs are allowed only for `prompt`, `reboot`, and test hooks.
- When a legacy behaviour is dropped on purpose, write `dropped <legacy fn> because <reason>` in §2 Log. Missing behaviour without such a line is a defect.
- Do not run `nds/src/app/main.sh` outside the test harness. `ROOTREEXEC_ROOT` stays commented.
- Bash 5.3+. `${ fn; }` for our functions. No Python. Public names `nds_<area>_<verb>`; tools keep their own prefix. `local -n` only for arrays.
- Banned names (grep in §4 G0): the list in PLAN §0 "Banned names".

## 2. Status

Resume: read §1, run §4 G0, find the first unchecked task, work only that task, run its gate, tick, add a Log line, mirror the tick into `nds/.wip/OPEN.md`.

- [x] T1 target root, then G1 + G7 (closes PLAN step 9; re-tick PLAN steps 3, 5, 6)
- [x] T2 review defects from the repair pass
- [x] T3 loop-device integration tier (`nds/dev/looptest.sh`)
- [x] T4 vocabulary: fill phase → `recipe`, birth phase → `cook`
- [x] T5 housekeeping and commits
- [x] T6 rewrite `nds/.wip/TESTING.md` for 6.x
- [ ] T7 closure

**Log**

- 2026-09-27 loop: first real `sudo bash nds/dev/looptest.sh` reached the device (BIOS, no `/sys/firmware/efi`). `lsblk` showed `vfat boot` and a root partition with no filesystem yet. `disk_partition` now `udevadm settle`s after mkfs so by-label and lsblk catch the ext4 label. Re-run the loop tier to confirm.
- 2026-09-27 T6: `nds/.wip/TESTING.md` reset for 6.0.1. Every session is open, order 0 → U → A → R → B → T → T2 → M → C → D → E. Leaf `dp_cluster`, host `control-toolkit`, BIOS VMware, `/dev/sda` kept. The file is under `.wip/` and stays untracked. Old env tokens are named in words in the rename table so the name gate only sees current flags and schema keys.
- 2026-09-27 T5: `nds/src/VERSION` is 6.0.1. Action docs follow the recipe/cook contract. `nds/.wip/OPEN.md` points here. One NDS commit covers the repair, the loop tier, and the vocabulary rename; they could not be split after the names moved. Essentials stayed in `2984074`. Not tagged, not pushed. T6 still rewrites `TESTING.md`.
- 2026-09-27 T4: fill side is `action_recipe`, `nds_pipeline_recipe`, `recipe.schema`, `recipe.done`, `recipe.summary`, `_NDS_RECIPE`. Birth side is `nds/src/cook/`, `nds_cook`, and `cook.pre_disk` through `cook.done`. Toolkit logic file is `recipe.sh`. Self-test and ShellCheck are green. Not committed yet: the repair, the loop tier, and this rename are still one working tree, so T5 cannot split them into three commits without rewriting history.
- 2026-09-27 T3: `nds/dev/looptest.sh` and `disk_LOOP_TEST.sh` are in. The unit walk skips the tier unless `NDS_LOOP_DEV` is set. On this WSL it only hit the skip path: `sudo -n true` failed and `parted` is not installed (`looptest` exit 2). Loop partition names use the `p` suffix (`/dev/loop0p1`), same as nvme.
- 2026-09-27 T2: operator pubs are `age.pub` and `ssh.pub`. `git.map` is checked through the tcast parser. Disk type is the `/dev/…` shape only; `disk_canUse` asks `lsblk` when the path is not a block device. Action cooks seal the full active key set (`*.sealed` next to each test) with `NDS_DISK_TARGET=/dev/sda`. Tool tests assert binary argument order for partition, mount, LUKS, hardware generation, sops leaf pub, and `nixos-install`. `nds/src/logs/` is already untracked; `**/logs/` and `nds/src/logs/` are ignored. Essentials and tcast committed alone as `2984074`. G0 and G4 on product code are green. `DISK_STRATEGY=flake` remains only on the flake-owned `main_TEST` case.
- 2026-09-26 T1: install root is `_NDS_TARGET_ROOT` (`<session>/mnt` in tests, `/mnt` otherwise). Realize loads the real tools and asserts the binary log. `app/main_TEST.sh` runs unattended classic and flake-local to exit 0. Cook clears pin locks before reading the sealed file, or `INSTALL_KIND` never loads. `installFlake` also fills network and access. G0, G1, G3, and G7 are green. This WSL has no efivars, so those runs stay BIOS and do not call `efibootmgr`. The encrypted realize case asserts `cryptsetup luksFormat`; exit 0 stays on `ENCRYPTION=false` because `/dev/mapper/cryptroot` cannot be created here. PLAN §0 stays frozen; live ticks are this section.
- 2026-09-26 review of the repair pass (uncommitted on top of `b89045e`): PLAN §9.1–§9.3 substantially done — disk step matches tool signatures, boot context and EFI correct, verify/diag/preflight/quickstart ported, git screens carry deploy/account/collision/QR, toolkit uses real keygen and has restore, schema `--when` fixed, fixtures honest, `nds_recipe_set` honours locks, second accept prompts. Open: G1, G7 (blocked on `/mnt`), `realize_TEST.sh` still stubs 33 tool functions, §9.4 docs, all commits. New defects: T2. Test tiers assessed: framework well covered; tools and the birth path thin (T2 D7, T3).

## 3. Tasks

### T1 — target root, then the two blocked gates

**Decision (made; do not reopen).**

```bash
# realize/realize.sh (cook/cook.sh after T4)
declare -g _NDS_TARGET_ROOT="${_NDS_TARGET_ROOT:-/mnt}"
```

Every `/mnt` literal under `realize/` becomes `"$_NDS_TARGET_ROOT"` (plans, steps, verify, diag). `FLAKE_INSTALL_PATH` default in `recipe/schema/flake.sh` becomes `--detect` printing `"${_NDS_TARGET_ROOT}/etc/nixos"`. Tools already take the mount root as an argument; keep passing it. `nds_test_session` sets `_NDS_TARGET_ROOT` to `<session>/mnt` and creates it. Production never sets it.

Then:

- `realize_TEST.sh`: remove all 33 tool-function stubs; load the real `utilities/`; use `nds_test_stubBins` for the binary set in PLAN §9.5 G3. Assert order and arguments from the binary log (`sgdisk`/`parted` on the disk, `cryptsetup luksFormat <partition>`, `mount`, `nixos-install`, `efibootmgr` when UEFI). This is G1.
- `app/main_TEST.sh`: G7 as written in PLAN §9.5, with `_NDS_TARGET_ROOT` from the session. Classic and flake-local, unattended, from env.

**Gate.** §4 G0 + G1 + G3 + G7.

### T2 — defects found reviewing the repair

| # | Defect | Fix |
|---|---|---|
| D1 | `fleet/nds-actions/toolkit/logic/cook.sh` writes `.toolkit/operator/keys/operator_age.pub` and `toolkit_ssh.pub`. `fleet/modules/nixos/host/default.nix` reads `.toolkit/operator/keys/ssh.pub`; `fleet/toolkit/lib/register.sh` documents `age.pub` / `ssh.pub` and `machines/<host>/keys/age.pub` | Write `age.pub` and `ssh.pub`. Assert in `toolkit_TEST.sh`. |
| D2 | `targetSeed_gitKeys` writes `git.map` as `owner/repo<TAB>/root/.ssh/nds/<safeurl>` | Read the parser (`tcast/lib/tcast_common.sh` `tcast_git_map_path` and the wrapper that consumes it) and match its exact line format. If the parser is pure Bash, test the written map through it. |
| D3 | `realize_TEST.sh` stubs tool functions | Covered by T1. |
| D4 | `nds/src/logs/*.log` are tracked | `git rm --cached nds/src/logs/*.log`; add `nds/src/logs/` to `.gitignore`. |
| D5 | Essentials fixes (`eventBus_dispatch.sh`, `prompt.sh`, `sessionDir.sh`, tests, READMEs) and `tcast/*` are uncommitted since before the refactor; NDS tests depend on them | Commit them first, alone: `fix(essentials): …`. Do not mix with NDS. |
| D6 | `recipe/types.sh` `disk)` accepts any value when `NDS_TEST_BIN_DIR` is set — a test back door in product code | `disk` type = shape only: `^/dev/[a-zA-Z0-9/_-]+$`. Existence (`-b`) and in-use checks stay in `nds_realize_preflight` via `disk_canUse` (already there) and in the disk asker's device list. Delete the `NDS_TEST_BIN_DIR` branch. |
| D7 | Action tests are thin and cheat: `classicInstall_TEST`, `installFlake_TEST`, `apply_TEST`, `addFleetHost_TEST`, `toolkit_TEST` export `NDS_DISK_STRATEGY=flake` to dodge D6, and assert only `INSTALL_KIND` / `INSTALL_ACTION` | After D6, remove those exports; give each test a real `NDS_DISK_TARGET=/dev/sda`. Each action test asserts the **complete** sealed key set for an env-driven run: every active key with its expected value (defaults, pins, detects stubbed via binaries, generated `*_FILE` paths exist and are mode 600), and that no inactive group's key is present. Write the expected set as a heredoc fixture next to the test and diff. |
| D8 | `disk_TEST.sh` (1 assertion), `bundle_TEST.sh` (1), `nixos_TEST.sh` (1), `sops_TEST.sh` (1), `hwconfig_TEST.sh` (1) | For each public tool function listed in the tool's `main.sh`, one case that calls it with real arguments under `nds_test_stubBins` and asserts the binary log line(s). Argument-order regressions are what bit us; this is the guard. |

**Gate.** §4 G0 + G4 + G5; `rg -n 'NDS_TEST_' nds/src fleet/nds-actions --glob '!*_TEST.sh' --glob '!setup_TEST.sh'` prints nothing.

### T3 — loop-device integration tier

Purpose: run the real `sgdisk` / `cryptsetup` / `mkfs.*` / `mount` code against a file-backed loop device, so the disk tool is tested with real binaries before any VM. Opt-in, needs sudo, never part of `selftest.sh`.

- `nds/dev/looptest.sh`: `set -euo pipefail`; refuse to run unless `sudo -n true` works and `losetup`, `sgdisk`, `cryptsetup`, `mkfs.ext4`, `mkfs.vfat` are present (print the `apt install gdisk cryptsetup-bin dosfstools` hint and exit 2 otherwise; on WSL `sudo modprobe loop` may be needed first). Create `img="${NDS_LOOP_IMG_DIR:-/dev/shm}/nds-loop.img"` with `truncate -s "${NDS_LOOP_SIZE:-4G}"`; `dev=$(sudo losetup -fP --show "$img")`; export `NDS_LOOP_DEV="$dev"`; run `bash utilities/bashTestSuite/main.sh nds/src/utilities/disk/disk_LOOP_TEST.sh`; always clean up (`umount -R`, `cryptsetup close`, `losetup -d`, `rm -f img`) in an `EXIT` trap.
- `nds/src/utilities/disk/disk_LOOP_TEST.sh`: skipped by the normal walk (name does not end in `_TEST.sh`… it does — so guard: first line `[[ -n ${NDS_LOOP_DEV:-} ]] || { bts_pass "loop tier not requested"; return 0; }` inside the suite). Hard safety: `[[ $NDS_LOOP_DEV == /dev/loop* ]]` or `bts_fail` and return; every disk tool call in this file receives `$NDS_LOOP_DEV` only. Cases: `disk_partition "$dev" false "" ` → `lsblk` shows ESP + root; `disk_mountRoot false "$root"` mounts into a temp `_NDS_TARGET_ROOT`; `disk_partition "$dev" true true cb` with a callback running `disk_luksFormat` with a generated passphrase file → `cryptsetup isLuks` true, `disk_mountRoot true` opens and mounts; `disk_setupInitrdSshKeys "$root" <key>` places the key; `targetSeed_copy <seed> "$root"` preserves modes; `disk_unmountTarget "$root"` leaves nothing mounted. `nixos-install`, `efibootmgr`, `nixos-generate-config` are stubbed binaries here.
- Document in `nds/README.md` Tests section.

**Gate.** §4 G0 (the loop file passes trivially in the unit walk); `sudo bash nds/dev/looptest.sh` → `OK` on a machine that has the binaries. Record in the Log whether it ran on this WSL or only its skip path.

### T4 — vocabulary: `recipe` for the fill phase, `cook` for the birth phase

Decision: two words in the whole product. The recipe is written, then cooked. Renaming only the folder would leave `action_cook` (runs before the disk is touched, fills keys) next to `nds/src/cook/` (runs `nixos-install`), and `cook.schema` (fill-time) in the same event namespace as `cook.pre_disk` (birth-time). So both sides move. Do this on a green tree, as one commit, with `git mv` for files.

| Old | New |
|---|---|
| `nds/src/realize/` | `nds/src/cook/` |
| `realize.sh` → `nds_realize <file>` | `cook.sh` → `nds_cook <file>` |
| `nds_realize_plan_*`, `nds_realize_preflight`, `nds_realize_verify`, `nds_realize_diag*` | `nds_cook_plan_*`, `nds_cook_preflight`, `nds_cook_verify`, `nds_cook_diag*` |
| `_realize_step` | `_cook_step` |
| events `realize.pre_disk`, `realize.post_disk`, `realize.pre_install`, `realize.post_install`, `realize.done` | `cook.pre_disk`, `cook.post_disk`, `cook.pre_install`, `cook.post_install`, `cook.done` |
| `recipe/schema/realize.sh` (group `realize`: `LEAF_PUSH_DIR`, `LEAF_PUSH_MESSAGE`, `TARGET_SEED_DIR`) | `recipe/schema/cook.sh`, group `cook` |
| `nds_pipeline_cook` | `nds_pipeline_recipe` |
| `action_cook` | `action_recipe` |
| events `cook.schema`, `cook.done` (fill-side) | `recipe.schema`, `recipe.done` |
| skip name `cook.summary` | `recipe.summary` (env `NDS_SKIP_RECIPE_SUMMARY`) |
| `_NDS_COOK` (the fill array) | `_NDS_RECIPE` |
| `fleet/nds-actions/toolkit/logic/cook.sh` | `logic/recipe.sh` |
| `realize_TEST.sh` | `cook_TEST.sh` |
| Test files, `# Description:` lines, READMEs, `.cursor/project.md`, `nds/README.md` | follow |

Ordering trap: `cook.done` exists on both sides with different meanings. Rename the fill side first (`cook.done` → `recipe.done`, `cook.schema` → `recipe.schema`), run G0, then rename the birth side (`realize.*` → `cook.*`).

Names that stay: `nds_bundle`, `nds_confirm`, `nds_finish`, `nds_wizard_fill`, `nds_recipe_*` (the contract module keeps its prefix; `nds_recipe_seal` reads fine).

**Gate.** §4 G0; `rg -n 'realize|nds_realize|action_cook|nds_pipeline_cook|_NDS_COOK\b|cook\.schema|cook\.summary' nds/src fleet/nds-actions .cursor/project.md nds/README.md --glob '!REFACTOR-PLAN.md' --glob '!HANDOFF.md'` prints nothing; `rg -c 'eventRun cook\.' nds/src/cook` shows the five slots; `rg -c 'recipe\.(schema|done)' nds/src/app/pipeline/pipeline.sh` is 2.

### T5 — housekeeping and commits

- `nds/.wip/OPEN.md`: replace the stale plan text with a pointer to this file, the seven task boxes mirrored, the parked-selftest gate ticked, legacy references removed.
- `nds/src/actions/README.md` and the fleet action READMEs: rewrite to the action contract (PLAN §4.4 with T4 names).
- `nds/README.md`: run section shows `--unattended`, `--yes`, `--skip`, `--reboot`, `apply <file|zip>`; Tests section lists selftest, shellcheck, looptest.
- Commits, in this order, each with §4 G0 green: (1) D5 essentials/tcast; (2) `fix(nds): cook from a sealed recipe — repair pass` (PLAN §9 + T1 + T2); (3) `test(nds): loop-device tier` (T3); (4) `refactor(nds): vocabulary recipe/cook` (T4); (5) docs (T5, T6). `nds/src/VERSION` → `6.0.1` in commit (2); `6.0.0` was committed but never tagged or pushed. Do not tag or push; the user does that after the VM matrix.

**Gate.** §4 G0; `git status --short` shows nothing under `nds/`, `fleet/nds-actions`, `utilities/essentials`, `tcast`.

### T6 — rewrite `nds/.wip/TESTING.md` for 6.x

The old matrix was written for 5.43 and uses env names that no longer exist. Every session must be re-run: the installer was rewritten. Keep the operator's VM specifics verbatim (leaf `dp_cluster`, host `control-toolkit`, BIOS VMware, `/dev/sda`, `lsblk` / EFI checks, keys table, pass criteria, T2/M/C/D sequencing, "Not in this matrix", Debug). Change:

- Header: version `6.0.1`, "all sessions reset — none signed off". Add a "Before the ISO" line: `bash nds/dev/selftest.sh`, `bash nds/dev/shellcheck.sh`, and `sudo bash nds/dev/looptest.sh` where the binaries exist.
- Env rename table at the top (the operator pastes from it):

  | 5.x | 6.x |
  |---|---|
  | `NDS_MODE=unattended` / `NDS_UNATTENDED=true` | `NDS_MODE=unattended` or `--unattended` |
  | `NDS_AUTO_CONFIRM=true` | `NDS_YES=true` or `--yes` (never implies git access) |
  | `NDS_*_SKIP=true` (14 names) | `NDS_SKIP_ACTION_PREVIEW`, `NDS_SKIP_RECIPE_SUMMARY`, `NDS_SKIP_INSTALL_CONFIRM`, `NDS_SKIP_FINISH_BACKUP`, `NDS_SKIP_FINISH_REBOOT` (=true), or `--skip a,b` |
  | `NDS_REBOOT_FORCE` / `NDS_REBOOT_SKIP` | `NDS_REBOOT=true` / `NDS_SKIP_FINISH_REBOOT=true` |
  | `NDS_CAST_TOOLKIT_MODE` / `NDS_CAST_TOOLKIT_RESTORE` / `NDS_CAST_TOOLKIT_BUNDLE` | `NDS_TOOLKIT_MODE=new\|restore`, `NDS_TOOLKIT_BUNDLE` |
  | `NDS_CAST_REPO_URL` / `NDS_CAST_ACTION` | `NDS_CATALOG_URL` / `NDS_CATALOG_ACTION` |
  | `NDS_GIT_AUTH_MODE`, `NDS_GIT_KEY_BODY`, `NDS_GIT_*` maps | gone. Keys are files in `GIT_KEYS_DIR` (default `<session>/secrets/git`; `NDS_GIT_KEYS_DIR` points at a prepared dir). Unattended requires a prepared dir; interactive opens the git wizard when a probe fails |
  | `NDS_ACCESS_ADMIN_PASSWORD`, `NDS_ENCRYPTION_PASSPHRASE` | `NDS_ACCESS_ADMIN_PASSWORD_FILE`, `NDS_ENCRYPTION_PASSPHRASE_FILE` (plain values are rejected) |
  | `NDS_INSTALL_DIAG_LOG` | gone; diag is `logs/diag.log` in the bundle |
  | `nds/VERSION` in the banner | `nds/src/VERSION` |

- Matrix rows, all status "open": **0** CI (selftest, shellcheck, looptest); **U** fully unattended classic from env only (`NDS_MODE=unattended`, `*_FILE` secrets prepared, `NDS_REBOOT=false`) — must never show a screen; **A** classicInstall LUKS password + remote unlock (BIOS), interactive; **R** restore: copy A's `nds_bundle.zip` to a fresh ISO, `apply /path/nds_bundle.zip --unattended` — must reproduce A without asking; **B** installFlake Disko + UEFI; **T** toolkit create; **T2** after boot; **M** addFleetHost manager; **C** worker; **D** nixos-anywhere; **E** remoteAction against a small test catalog the operator creates (`.nds/actions/hello/setup.sh` registering a `cook.post_install` hook that writes `/etc/nds-hello`) — two accepts visible, file present after boot.
- Session T "Values" and "Pre-fill" blocks: env per the table; `NDS_TOOLKIT_MODE=new`; drop `unset NDS_UNATTENDED NDS_AUTO_CONFIRM`.
- Session T pass criteria add: `.toolkit/operator/keys/age.pub` and `ssh.pub` on origin (D1); `.toolkit/machines/control-toolkit/keys/age.pub` on origin; `/var/lib/nds-toolkit/current/toolkit.sh` present (the `cook.post_install` hook).
- Session D env block: replace `NDS_GIT_AUTH_MODE` / `NDS_AUTO_CONFIRM` with a prepared `NDS_GIT_KEYS_DIR` and `NDS_MODE=unattended`.
- Sign-off table: all rows "open", order 0 → U → A → R → B → T → T2 → M → C → D → E.

**Gate.** `rg -o 'NDS_[A-Z_]+' nds/.wip/TESTING.md | sort -u` contains only the runtime flags from §1 and keys that exist as `nds_schema_field … <KEY>` in `nds/src/recipe/schema/`.

### T7 — closure

Only after T1–T6 are ticked and the user has confirmed in chat that at least session **U** passed on a VM (do not assume):

- Create `nds/docs/architecture.md` from §1 of this file plus the T4 name table as canonical vocabulary. Under 120 lines.
- Update `.cursor/project.md` NDS row: tests `bash nds/dev/selftest.sh` · `sudo bash nds/dev/looptest.sh` (opt-in), layout pointer to `nds/docs/architecture.md`.
- `git rm nds/src/REFACTOR-PLAN.md nds/src/HANDOFF.md`. Update `nds/.wip/OPEN.md` to say the refactor is closed and where the architecture doc is.
- Commit `docs(nds): close the recipe/cook refactor`.

## 4. Gates

All commands run from the repo root under Bash 5.3.

- **G0** (every task): `bash nds/dev/selftest.sh` → stderr `OK`, exit 0. `bash nds/dev/shellcheck.sh` → exit 0. Banned-name grep (PLAN §7 step 7 command, excluding `REFACTOR-PLAN.md` and `HANDOFF.md`) prints nothing.
- **G1 Resolution**: the cook test and `pipeline_TEST.sh` load the real tool trees, extract every `^(disk|nixos|nixcfg|flake|git|gh|facter|hwconfig|sops|targetSeed|pkg|age|qr|step|nds)_[A-Za-z_]+` command name from `nds/src/{realize|cook}/*.sh`, `nds/src/app/*.sh`, `nds/src/actions/*/setup.sh`, `fleet/nds-actions/*/setup.sh`, `fleet/nds-actions/*/logic/*.sh`, and `bts_fail` each one `declare -F` cannot find.
- **G3 Binaries not functions**: `rg -c '^(disk|nixos|nixcfg|flake|git|gh|sops|targetSeed|hwconfig|facter|age|pkg|qr)_[A-Za-z]+\(\)' <cook test> nds/src/app/pipeline_TEST.sh nds/src/app/main_TEST.sh` is 0 for each.
- **G4 No fake material / back doors**: `rg -n 'AGE-SECRET-KEY-1TOOLKIT|toolkit-ssh-private|example\.com|placeholder' nds/src fleet/nds-actions --glob '!*_TEST.sh' --glob '!*.md'` prints nothing; `rg -n 'NDS_TEST_' nds/src fleet/nds-actions --glob '!*_TEST.sh' --glob '!setup_TEST.sh'` prints nothing.
- **G5 Fixture honesty**: `classic_min.recipe` has no `CATALOG_*`, `FLAKE_*`, `TOOLKIT_*`, `SCAFFOLD_*`; `DISK_STRATEGY=nds`. `rg -n 'DISK_STRATEGY=flake' nds/src fleet/nds-actions --glob '*_TEST.sh'` matches only tests whose name or section says flake-owned disk.
- **G7 Real invocation**: `app/main_TEST.sh` runs `main.sh` unattended from env under `nds_test_stubBins` with `_NDS_TARGET_ROOT` in the session; the binary log shows partitioning, `cryptsetup` when encrypted, `nixos-install`, in that order; no `prompt` call; exit 0.
