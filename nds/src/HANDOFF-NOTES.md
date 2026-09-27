# Notes for the next session

Written 2026-09-27 after the test-fix pass on top of `b35a4ef`. The user stopped further loop-tier fixes. Do not start another loop attempt unless they ask.

`nds/src/HANDOFF.md` is still the execution spec. T1–T6 are ticked. T7 stays blocked until the user confirms session **U** on a VM. Nothing here is tagged or pushed.

Self-test (`bash nds/dev/selftest.sh`) was green after the unit-test fixes. The loop tier is not part of that gate.

## Test failures after the handoff commit

The user ran the suite from `nds/` and then `sudo bash dev/looptest.sh`. Four separate problems showed up. The first three are fixed. The loop tier is not.

### 1. No-tty action select

`nds/src/app/action/action_TEST.sh`

`suite_action`, case "no terminal without NDS_ACTION". Expected `nds_action_select` to fail without calling the menu. It returned 1 and still set `menu=1`.

`nds_action_select` only skips the menu when `[[ ! -t 0 ]]`. The suite does not close stdin, so a run from a real terminal still has a tty and the menu stub runs. The case was asserting "no terminal" without making stdin a non-terminal.

Change: that one call is `nds_action_select </dev/null 2>/dev/null`. Re-ran the file under `script` (a real pty) and it passed. Header date bumped to 2026-09-27.

### 2. `rg` is not on the operator PATH

`nds/src/setup_TEST.sh`, `nds_test_assertResolved`

`pipeline_TEST.sh` and `cook_TEST.sh` failed as leaks:

```
setup_TEST.sh: line 176: rg: command not found
```

bashTestSuite merges the child stdout and stderr, so a missing `rg` is a leak, not a normal error. `nds_test_assertResolved` extracted command names with `rg -o -r`. This machine has GNU grep and does not have `rg` on `PATH` (Cursor's copy is not the operator's).

Change: the extractor is `grep -h -oE` with the same boundary pattern. The match includes the boundary character, so the reader strips a leading or trailing non-name character before `declare -F`. Compared against `rg` on the same file set: both sides were the same 106 names. Header date bumped to 2026-09-27.

### 3. Stub shims wrote files into the repo

`nds/src/setup_TEST.sh`, inside every binary shim built by `nds_test_stubBins`

Any argument after `-o` or `-f` was treated as an output path. The shim wrote `AGE-SECRET-KEY-TESTONLY` there and a sibling `.pub`. Three real invocations are column flags, not paths:

| Call | Files created in the cwd |
|---|---|
| `lsblk -dn -o NAME` (`disk_canUse`) | `NAME`, `NAME.pub` |
| `findmnt -n -o SOURCE` (`disk_findmntSource`) | `SOURCE`, `SOURCE.pub` |
| `blkid -o value` (`disk_blkidUuid`, `disk_blkidType`) | `value`, `value.pub` |

`sudo bash dev/looptest.sh` runs as root, so the files were root-owned. Copies appeared both in `nds/` and at the repo root, depending on where the suite was started. They are not secrets and not fixtures.

A first cut limited the write to `age-keygen -o` and `ssh-keygen -f` only. That broke `cook_TEST.sh`: `facter_write` runs `nix … -o <absolute facter.json>` and then requires the file to be non-empty (`[[ -s dest ]]`). The old shim had been creating that file.

Final rule:

- Absolute path after `-o` or `-f`: still write the stub key there (facter, age, ssh).
- Relative path, and the binary is `age-keygen` or `ssh-keygen`: write under `${TMPDIR:-/tmp}/nds-test-stubs/`.
- Relative path for anything else (`NAME`, `SOURCE`, `value`): write nothing.

The junk files were deleted. Cook and disk unit tests passed after this.

### 4. Loop tier — not finished

`sudo bash nds/dev/looptest.sh` on this WSL. The user asked to stop after the run below. Do not "fix it again" unless they ask.

What the runs showed, in order:

1. Layout check failed. `lsblk` on a BIOS disk (no `/sys/firmware/efi`) was disk, empty `bios_grub`, `vfat boot`, and a root line with no type. `disk_partition` had already returned 0. `lsblk` was reading udev, and udev had published the boot filesystem (formatted first) and not the ext4 label yet.
2. Next run: `unencrypted disk_partition failed`, with stderr thrown away, so the reason was invisible.
3. After stderr was kept: `cryptsetup luksFormat` printed `Are you sure? (Type 'yes' in capital letters)` and slept with zero CPU until Ctrl+C. On a tty, `luksFormat` asks even when `--key-file` is set. The whole tier should be under a minute; that wait was the prompt.
4. Last run, after `--batch-mode`: `passed=2` (unencrypted layout and unencrypted mount). Then:

```
FAIL cryptsetup isLuks failed for /dev/loop0p3
LEAK
Device /dev/loop0p3 does not exist or access denied.
```

The encrypted call is `disk_partition "$dev" true true _loop_luks`. The third argument is `uefi_mode`, so this pass forces UEFI: boot is `p1`, LUKS root is `p2`. The check that follows picks `p3` whenever `/sys/firmware/efi` is absent, which it is on this machine. `cryptsetup isLuks /dev/loop0p3` then writes the "does not exist" line to stderr, and the suite records that line as a leak because the call is not redirected.

So the unencrypted half of the tier did pass on the last run. The encrypted assertion looks at the wrong index, and its stderr leaks. That mismatch was introduced in this pass (the host-firmware branch). The product partition for that call really is `p2`.

#### `nds/src/utilities/disk/ops/disk_partition.sh`

Added, and wired in after the existing `sleep 2`:

- `_disk_publish` — `sync`, then `udevadm settle --timeout=15`. Called once before `mkfs` (so udev is not holding the new nodes) and once after (so `lsblk` and `/dev/disk/by-label` see the labels).
- `_disk_reread` — `partprobe`, and on `/dev/loop*` also `losetup -c` and `partx -u` (else `partx -a`). Loop nodes often do not appear from `partprobe` alone.
- `_disk_part_ready` — for `/dev/loop*` only, wait up to 5s for `-b`. Other disks return immediately, so the stubbed `disk_partition /dev/sda` unit test does not wait or run `partx` on a real disk.
- Unencrypted `mkfs.ext4` gained `-F`, so a udev open does not make mkfs refuse the partition.

#### `nds/src/utilities/disk/ops/disk_luks.sh`

- All three `luksFormat` lines gained `--batch-mode`, placed after the existing arguments so the unit-test greps for `cryptsetup luksFormat --type luks2 … --key-file` still match.
- `mkfs.ext4` on `/dev/mapper/cryptroot` gained `-F` for the same udev reason.

#### `nds/src/utilities/disk/disk_LOOP_TEST.sh`

- Unencrypted and encrypted `disk_partition` failures keep stdout and stderr and put them on one line in the fail message. That is how the `YES` prompt became visible.
- After the unencrypted format, `lsblk` is polled for up to 5 seconds for `vfat`, `boot`, `ext4`, and `nixos`. The fail text also includes `blkid`.
- `isLuks` uses partition 2 when `/sys/firmware/efi` exists and partition 3 otherwise. That is the remaining bug, described above. The encrypted `disk_partition` call still passes `true` as `uefi_mode`.

`disk_TEST.sh` and `cook_TEST.sh` passed after these edits. The in-flight loop run is not re-run here.

### Also touched, not product code

`nds/src/HANDOFF.md` §2 only: T6 ticked, plus two log lines (T6, and the first real loop run). §1 and §4 were not edited.

`nds/.wip/TESTING.md` (gitignored): rewritten for 6.0.1, every session open, order 0 → U → A → R → B → T → T2 → M → C → D → E. The env-rename table's 5.x column cannot contain `NDS_[A-Z_]+` tokens or the T6 gate fails. Old names are described in words. The 6.x column keeps the real flags and schema keys. Gate `rg -o 'NDS_[A-Z_]+' nds/.wip/TESTING.md | sort -u` was clean against §1 flags plus `nds_schema_field` keys (77 keys, 32 names used).

`nds/.wip/OPEN.md`: T6 tick mirrored. Also gitignored.

Dirty in the tree and not part of this test pass: `.gitignore` (a line ignoring `nds/src/HANDOFF.md`), `AGENTS.md` (one sentence about disagreeing sources), and untracked `.cursor/rules/*` plus `.cursor/skills/`. Do not assume those belong in an NDS commit.

## Issues while executing `HANDOFF.md`

Committed state is `b35a4ef` `refactor(nds): cook a sealed recipe` (VERSION `6.0.1`) plus `2984074` for essentials/tcast. The user agreed the repair, the loop tier, and the vocabulary rename could not be split after the names moved, so they are one NDS commit. Not tagged. Not pushed.

T7 does not start until T1–T6 are ticked (they are) and the user says session U passed on a VM. Do not assume that.

### T1 — target root, G1, G7

- The sandbox and this WSL cannot create `/mnt`. An `unshare` mount namespace was blocked and was not retried. Install root is the internal `_NDS_TARGET_ROOT` (default `/mnt`), set only by `nds_test_session` to `<session>/mnt`. Not a flag, not a recipe key.
- `nds_cook` must clear process-global schema locks (`*|locked`) before `nds_recipe_loadFile`. Otherwise pinned `INSTALL_KIND` / `INSTALL_ACTION` are skipped on load and validate says required.
- `installFlake` has to fill `network` and `access`. Without those groups, cook's `enableAll` fails on `NETWORK_HOSTNAME` / `ACCESS_ADMIN_USER`.
- App load must `nds_requireUtility` the tool set (pkg age disk flake git hwconfig facter nixcfg nixos qr sops targetSeed) before `eventRun utility.load`. Otherwise flake validate says "tool not loaded".
- This WSL has no `/sys/firmware/efi/efivars` and cannot create `/dev/mapper/cryptroot`. Exit-0 cooks stay `ENCRYPTION=false` and BIOS. The encrypted case asserts `cryptsetup luksFormat` and does not require exit 0. `efibootmgr` is not called: `disk_efiRegister` returns before it when the live system is not UEFI.
- Empty `DISK_TARGET` (flake-owned) must only check `${_NDS_TARGET_ROOT}/boot/grub/grub.cfg`. Calling `disk_grubBiosBootOk ""` failed the cfg check even when the file existed.
- Classic `nixos_copyConfigs` must not copy a directory onto itself; the test needs a separate source dir or `nixos-install` never runs.
- Tests that invoke `main.sh` must use `env -i`. A dirty user environment leaks locked `NDS_*` keys into the run.
- `${ fn; }` is the repo's command substitution. `session=${ _NDS_TEST_SESSION; }` is a command name, not a variable. Use `session=$_NDS_TEST_SESSION`.
- Logger: `log`/`info` on stdout fail the suite. Tests set `logger_setMinLevel warn` or `error` and redirect cook/main stdout.

### T2 — review defects

- Operator pubs are `.toolkit/operator/keys/age.pub` and `ssh.pub`. Machine pub is `.toolkit/machines/<host>/keys/age.pub`, written in cook via `sops_writeLeafPub`.
- `git.map` is `owner/repo<TAB>/root/.ssh/nds/<safeurl>`. The target gets `tcast-git-ssh` plus `tcast_common.sh` and `tcast_git_ssh.sh`, not a full tcast tree. Lookup is tested through the tcast parser.
- Disk type is the shape `^/dev/[a-zA-Z0-9/_-]+$` only. No `NDS_TEST_` branch. `disk_canUse` is `[[ -b ]]` or `lsblk -dn -o NAME` printing a line. The lsblk stub prints `stubdisk`, which is why a non-block path passes `canUse` under stub bins.
- `nds_session_logs_root_dir` is the function name. An extra underscore in the definition was a real bug.
- Action sealed fixtures live next to the tests, use `@SESSION@`, and are diffed after materialize/seal. Boot env is forced `NDS_BOOT_UEFI_MODE=false` `NDS_BOOT_LOADER=grub` so fixtures are not host-dependent. `systemd-detect-virt` stub prints `none`, so `PLATFORM_RUN_ON_VM` stays false and the VM fields stay inactive.
- Comments that said "placeholders" matched the G4 fake-material grep. Reworded to "markers". Product code has no `NDS_TEST_` and no fake key material. The docs `HANDOFF.md` and `REFACTOR-PLAN.md` still name `NDS_TEST_` and will match a grep that does not exclude `*.md`.

### T3 — loop tier, as committed

- `nds/dev/looptest.sh` is opt-in and not part of selftest. On the agent shell, `sudo -n true` fails (`/etc/sudo.conf` owned by uid 65534) and that was recorded as exit 2. The user's own shell can sudo; the later runs above are from there.
- `parted` was missing at commit time. It is installed now. The loop script also requires `losetup sgdisk cryptsetup mkfs.ext4 mkfs.vfat mkfs.fat`.
- Loop partition names use the `p` suffix (`/dev/loop0p1`), same as nvme. `disk_partition` still has a hardcoded `umount -R /mnt` that is not the session root.
- `disk_LOOP_TEST.sh` returns immediately when `NDS_LOOP_DEV` is unset, so the unit walk stays green.

### T4 — vocabulary

- Fill side first: `cook.done` → `recipe.done`, `cook.schema` → `recipe.schema`, `action_cook` → `action_recipe`, `nds_pipeline_cook` → `nds_pipeline_recipe`, `_NDS_COOK` → `_NDS_RECIPE`. Then birth side: `realize.*` → `cook.*`, tree `nds/src/cook/`, entry `nds_cook`. A global `realize`→`cook` replace before the fill rename collides the two meanings.
- Gate `rg -c 'recipe\.(schema|done)' nds/src/app/pipeline.sh` is 4 (create + run for each), not 2. Both events are created and run. Do not collapse them.
- The same global replace rewrote the root `README.md` `src.old/realize` into `src.old/cook` because `realize` was a substring. That one line was put back to `nds/src/cook/` and `nds_cook` before the commit.
- Git rename detection in `b35a4ef` paired some cook files by similarity (for example old `steps_hardware.sh` with `steps_boot.sh`). The tree content was what selftest ran. The pairing is history cosmetics.
- `_git_gh_realize` was renamed `_git_gh_nixBuild` so the banned `realize` grep stays empty.

### T5 — commits and docs

- Essentials stayed in `2984074`. The NDS commit message says the three pieces could not be split.
- `.wip/` is gitignored. `OPEN.md` and `TESTING.md` were not in `b35a4ef`.
- `nds/src/REFACTOR-PLAN.md` §0 says the plan is superseded by the handoff. Do not tick §0. Open the plan only for a section the handoff cites.

### T6 — test matrix

- Gate is `rg -o 'NDS_[A-Z_]+'` against runtime flags from handoff §1 and real `nds_schema_field` keys. Writing the historical 5.x names as `NDS_…` tokens fails that gate even though the operator needs to recognise them. They are words in the 5.x column. Paste from the 6.x column.
- `NDS_SKIP_ACTION_PREVIEW` and the other `NDS_SKIP_<NAME>` forms are the §1 flag, not schema keys.
- `NDS_GIT_PERSIST_ACCESS` is the schema field `GIT_PERSIST_ACCESS`.

### Traps that are still easy to repeat

- Never stub an NDS tool function. Stub binaries with `nds_test_stubBins`. Function stubs are only for `prompt`, `reboot`, and test hooks.
- `NDS_TEST_*` names only in `nds/src/setup_TEST.sh` and `*_TEST.sh`.
- Do not run `nds/src/app/main.sh` except under the harness with stub bins and `ROOTREEXEC_ROOT` unset.
- Runtime flags stay the §1 list. Do not add one. `_NDS_TARGET_ROOT` is internal.
- `rg -c` counts lines. Do not "fix" the recipe event count from 4 to 2.
- No Python. Do not edit `.cursor/rules` unless asked. Do not amend `b35a4ef` or `2984074`.

## User questions about the refactored tree

Asked 2026-09-27. Each number is one exchange: what the user asked, what was answered, then what the user said back. A missing second `user:` means they did not follow up on that number. Nothing in the second `user:` turn is implemented.

1)
user:
What are sealed files in action dirs?
llm:
A `*.sealed` file is a test fixture, not something the installer reads. The action test fills a recipe, materializes secrets, seals it, replaces the session path with `@SESSION@`, and diffs that text against the file. `classicInstall.sealed` is the full classic recipe that unattended fill is supposed to produce: pins, defaults, generated `*_FILE` paths, BIOS/grub, `/dev/sda`. Same idea for `installFlake.sealed` and `apply.sealed`. The handoff asked for this in T2, because checking only `INSTALL_KIND` hid a wrong key set. The refactor plan already had `recipe/fixtures/*.recipe` as cook inputs. The `.sealed` files are the other end: the fill output.
user:
If I understand this correctly, in an action folder we have a `*_TEST.sh` file and a sealed file, both only used to test that action's contract. If that is true, move those into a `test` folder inside the action folder.

2)
user:
Why do actions have tests? What exactly are we testing? Those should just call already tested logic, features, and tools of NDS.
llm:
They do not re-test disk, nixos, or sops. They test the action contract those tool tests never see: which groups `action_groups` turns on, which keys `action_pins` locks, what unattended fill plus `nds_recipe_materialize` writes, and that generated secret files are mode 600. `installFlake` also has `logic/` (probe, leaf, hosts). That fill behaviour is the action's, so the test sits next to `setup.sh`. The plan's rule was that actions are thin recipe makers and must not partition or call `nixos-install`. The tests stay on that side of the line. An older note that they only assert `INSTALL_KIND` and `INSTALL_ACTION` is out of date. The classic test diffs the whole sealed file.
user:
Same as 1. If the test file and the sealed file are only for that contract, move both into a `test` folder inside the action folder.

3)
user:
Why is action logic in its own folder, and session logic in its own folder, while some session-related logic sits directly in the app folder? Utility has its own folder as well.
llm:
That split is the refactor plan's tree, not a later idea. `app/action/` is discover, select, and the menu. `app/session/` is mode, skip names, dirs, cli, logs, failure, exit. `app/utility/` is only the loader `nds_requireUtility`. `confirm.sh`, `finish.sh`, and `pipeline.sh` sit in `app/` because the plan listed them as the pipeline stages, not as session helpers and not as an action. `main.sh` and `chrome.sh` are the entry. `features.sh` loads session, the utility loader, actions, confirm, finish, pipeline, then recipe, cook, and wizard. The old app was `settingsManager`, `bundleManager`, and `realize` mixed together. The plan pulled those apart. `app/realize/` and `app/settings/` are still on disk. The loader does not import them.
user:
Group things in folders in a way that matches the workflow. For example a pipeline folder, if that is the workflow of the NDS main script. The leading LLM should come up with the structure.

4)
user:
Are the lib files still used anywhere?
llm:
Both files are still sourced from `features.sh` on every run. They are the old helpers from 2026-08-16, kept because the plan said they are not essentials. `nds_lib_urandom_chars` is still called, from `disk_urandom.sh` and from nixcfg secret writing. `nds_lib_env_is_true` and `nds_lib_bool_parse` have no callers left. The old settings code used them to parse env booleans. The schema walkers replaced that. A plan log line that says `lib` is gone is wrong. The files are still there.
user:
Do not keep dead code. The project is already big and complex enough without dead functions, code, and files.

5)
user:
`steps_boot.sh` only contains UEFI, not legacy BIOS. Why?
llm:
`steps_boot.sh` only registers the UEFI firmware entry (`step_efi`). If `BOOT_UEFI_MODE` is not `true` it returns immediately. BIOS grub is not a second function in that file. `nixos_setBootContext` records grub plus UEFI false, and `nixos-install` writes the BIOS bootloader. `verify.sh` then checks `grub.cfg` and, when a disk is set, `disk_grubBiosBootOk`. The file header already says it is EFI-only. The old realize tree had the same split: NVRAM registration was its own step, because `nixos-install` does not create the EFI boot entry. The name `steps_boot.sh` is wider than the function.
user:
Understood, but would a `step_bootloader.sh` that handles both UEFI and BIOS make more sense, instead of one file for UEFI and BIOS handled somewhere else? Just wondering.

6)
user:
Why do plans contain logic that is only ever used by an action? Why is that code not in the action files? It looks like it should live in the action files.
llm:
The plan put `plan_classic.sh`, `plan_flake_local.sh`, and `plan_flake_remote.sh` in the birth tree on purpose. An action is forbidden to partition or call `nixos-install`. It only chooses groups and pins `INSTALL_KIND`. Cook picks the plan from that pin. `apply` reloads whichever action the sealed recipe names so hooks run again, then runs the same plan. If the classic sequence lived in `classicInstall/setup.sh`, a restore of a classic recipe would depend on that action file containing the birth steps. The old project already had this split: actions described the install, `realize/` performed it. The plans are that realize sequence after the rename. They are not action-private helpers that happened to land in the wrong folder.
user:
Understood, but either cook is generic — based on the recipe it calls different tools, passes different arguments, or chooses different branches — or the plans built into cook limit what an action can be. What are actions worth if they are limited by those plans?

An action should have all freedom when setting up a recipe. It should be almost limitless there. Cook should handle a recipe whether or not it has a dedicated plan for that meal. It should break the recipe into phases and handle them according to the recipe.

`classicInstall` and flake install share a lot of logic, some differs, and some is specific to an action. Hooks exist exactly for the specific parts. It gets complex when remote actions inject custom functions into hooks: loading that recipe later has to source and inject those remote files too, or the result will not match. That is exactly what was warned about to the lead LLM.

7)
user:
What is quickstart?
llm:
`bundle_quickstart.sh` writes `QUICK_START.md` into the bundle: hostname, what the zip contains, LUKS, remote unlock, sops, toolkit. The plan named that file. The first port left it as a stub. The repair pass filled it back in from the old bundle text, because the review called the stub a defect. It is operator notes for the machine you just installed, not a second installer.
user:
Ok.

8)
user:
What are fixtures?
llm:
`recipe/fixtures/` are cook-test inputs: small recipe files such as `classic_min.recipe` and `flake_local.recipe`. Cook loads them, seals them, and runs `nds_cook`. They are not shipped and not read in production. The plan called for `fixtures/*.recipe`. The `.sealed` files in the action dirs are a later, stricter fixture for the fill side.
user:
Same situation as 1 and 2, and only caused by 6. Understood.

9)
user:
What is schema?
llm:
The schema is the only declaration of recipe keys. `schema.sh` is the walker (group, field, `--when`, type, default, generator, lock). `schema/<group>.sh` is one file per group: install, disk, boot, access, and the rest. Defaults, validate, ask, summary, env import, and export all walk that table. The plan replaced the old design, which was about twelve preset files times five hooks (`defaults`, `configure`, `validate`, `summary`, `prompt_errors`) plus a per-type asker. That table was implemented. A second config system was not added beside it.

10)
user:
What is `generate.sh` if utilities are decoupled and standalone (age, sops, git)?
llm:
`generate.sh` runs at materialize, on the fill side, before the recipe is sealed. Cook is not allowed to generate secrets. It only copies `*_FILE` paths. The functions (`nds_generate_password`, `nds_generate_bytes`, `nds_generate_sshHostKey`, `nds_generate_ageKey`) are what schema fields name with `--generate`. They know recipe things the tools do not: `ACCESS_ADMIN_PASSWORD_LENGTH`, `--generate-when 'ACCESS_ADMIN_PASSWORD_AUTO=true'`. `age` and `sops` stay standalone and take arguments. `nds_generate_ageKey` calls `age-keygen` at this one moment. The old code generated secrets inside scattered ask and configure hooks. The plan pulled that into one place next to the schema.

11)
user:
Why is there a recipe store? Isn't there only ever one recipe active?
llm:
There is no list of recipes. `store.sh` is get, set, has, and the lock check on whatever associative array you pass by name. The plan killed the old global `CONFIG_DATA`. Fill owns `_NDS_RECIPE`. Cook loads a different `local -A` from the sealed file and must not see the fill array. Tests build more arrays from fixtures. "Store" is the plan's module name for those operations. One run still has one active recipe per phase. Two phases do not share the array.

12)
user:
Are utilities still used? If so, which ones, and which are not?
llm:
Yes. Every run loads pkg, age, disk, flake, git, hwconfig, facter, nixcfg, nixos, qr, sops, and targetSeed through `nds_requireUtility` in `features.sh`. That list is the live set. Disk, nixos, nixcfg, git, sops, flake, facter, hwconfig, and targetSeed are on the cook and fill paths. `pkg` is how `age` and the GitHub helper run a binary. `qr` is the git wizard card. No loaded utility was found that nothing calls. Paths inside them are action-specific. Disko code runs only for a flake disk strategy. Remote `nixos-anywhere` runs only for the remote plan. The plan kept the old utility families and added the rule that a tool takes arguments, does one job, and never prompts or reads the recipe array.

13)
user:
Tell me about the wizard: whose idea, why it is designed this way.
llm:
The wizard was the plan's idea, in its section on the interactive driver, and the old tree already had `nds/src/wizard/`. The old askers each checked the mode themselves, and there were about fourteen separate skip flags. The plan said unattended never enters `wizard/`, and `prompt` is only called from that tree. `ask.sh` walks the active schema fields and asks by type. `askers/` exists only where a plain prompt is wrong: disk, country, flake host, catalog, git access. `wizard/git/` is the deploy-versus-account flow, the collision retry, and the QR card, ported back during the repair because the first wizard pass had dropped those screens. That shape was followed. A second questioning style was not added.
