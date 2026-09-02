# NDS `src` layout

Entry: `app/main.sh`. Foundation log: `logger/`. Interactive chrome: `ui/`. Generic helpers: `lib/`. Ops: `utilities/`. Wizard warm chrome: `wizard/git/lib/git_warm.sh`.

## Top-level

| Path | Purpose |
|------|---------|
| `logger/` | Foundation logger (console + install log) |
| `lib/` | Small shared helpers for non-app (host IP, PEM, bool, urandom) |
| `app/` | Backbone: `moduleLoader`, `sessionControl`, `actionManager`, `utilityManager`, `settingsManager`, `bundleManager` |
| `ui/` | Interactive terminal UI (prompts, sections, stepAnimation) |
| `utilities/` | NDS-free `git` / `flake` / `qr` / `pkg` / `age` / `facter` (gh bin cache in `git/providers/git_github_bin.sh`) |
| `wizard/git/` | Git IO + bridge + warm chrome (`lib/git_warm.sh`) |
| `install/` | Install pipelines nested `disk/` `flake/` `classic/` `nix/` `verify/` + `nixcfg/` |
| `actions/` | One `setup.sh` per action |

Feature folders use `logic/` + `ui/` (+ colocated `*_TEST.sh`). Actions are a single `setup.sh`. Pure **data** under `data/` is not auto-sourced.

Shared test framework: repo-root `utilities/bashTestSuite`. Run: `bash nds/dev/selftest.sh`.

`nds_app_bootstrap` in `main.sh` is the only early load list. After an action is imported, `nds_app_prepareAction` loads settingsManager, then git / bundleManager / install.

App function names: `nds_app_<feature>_<layer>_<camelAction>` for actionManager. Domain features keep `nds_git_*` / `nds_install_*`. Settings store keeps `nds_cfg_*`.
