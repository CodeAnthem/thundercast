# NDS src conventions

Applies to `nds/src/` (`lib/`, `app/`, `logger/`, `ui/`, `utilities/`, `wizard/git/`, `install/`, `actions/`).

Entry: `nds/src/app/main.sh`. After an action is imported: settingsManager → `nds_requireUtility git|flake` → wizard/git / bundleManager / install as needed.

Shared tests: repo `utilities/bashTestSuite`. Product entry: `nds/dev/selftest.sh` (finds `*_TEST.sh`).

## Top-level

| Path | Role |
|------|------|
| `logger/` | Foundation logger (console + install log) |
| `lib/` | Generic helpers for non-app (no domain policy) |
| `app/` | Backbone: moduleLoader, sessionControl, actionManager, utilityManager, settingsManager, bundleManager |
| `ui/` | Interactive chrome (prompts, sections, stepAnimation) |
| `utilities/<name>/` | NDS-free libs via `nds_requireUtility` (`git_*` / `flake_*` / `pkg_*` / `qr_*` / `age_*` / `facter_*`); gh bin cache in `git/providers/`; warm chrome in `wizard/git/lib/` |
| `wizard/git/` | NDS git orchestration (wizard, maps, bridge) |
| `install/` | Disk / nixos-install / flake pipelines |
| `actions/<name>/` | One `setup.sh` (+ optional README) |

`fleet/nds-actions/` holds toolkit / addFleetHost (auto-discovered). Host CLI lives in `tcast/`, not under `nds/src/`.

## One concern

- Do not duplicate capabilities (loggers, lock parsing, parallel clone APIs).
- Features call `lib/`, `utilities/`, and wizard warm helpers; they do not re-own them.
- Prompts in `ui/`; pure work in `logic/`.
- Install / wizard/git pull via `nds_git_env_pullTo` + store API; lock fields via `flake_lock*`.

## File names

Basename must show the feature: `<feature>_<concern>.sh`. No generic `hosts.sh` / `key.sh` / `init.sh`.

Exceptions: `app/main.sh`; short names under `ui/` / `logger/`; builtin presets keyed by basename.

Tests: `*_TEST.sh` beside the feature (importer skips them).

## Function names

- Public `nds_*`, private `_nds_*` (except utilities: `git_*` / `_git_*` / `flake_*`).
- Domain: `nds_git_*`, `nds_install_*`, `nds_bundle_*`, `nds_cfg_*`, …
- No shortcut wrappers that only call another function.

## Loading

`nds_import_tree`: files, then `lib` → `logic` → `state` → `ui`, then other subdirs. Skips `tests/`, `data/`, `fixtures/`, `specs/`, `load.sh`, `_*`, `*_TEST.sh`.

Bash dispatch by string (`nds_step_exec`, traps, `${preset}_validate`) — grep the name before deleting.

## Action hooks

Required: `action_presets` **or** `action_config`, plus `action_preview`, `action_setup`. Optional: `action_presets_paths`, `action_on_accept`.
