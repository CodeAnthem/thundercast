# NDS `src` layout

Entry: `app/main.sh`. Shared UI: `ui/`. Generic helpers: `lib/`. Capability CLIs: `tools/`. Target helpers: `scripts/`.

## Top-level

| Path | Purpose |
|------|---------|
| `lib/` | Small shared helpers (host IP, PEM markers, bool, urandom) — no feature policy |
| `app/` | Backbone + core features (`actionHandler`, `settingsManager`, `session`, `bundle`) |
| `ui/` | Shared terminal UI only |
| `tools/` | Sourcable capabilities (`nds_pkg_*`, `nds_qr_*`, `nds_gh_*`, …) |
| `git/` | SSH keys, probe/clone, wizard; nested `access/`, `keys/`, `wizard/` |
| `install/` | Install pipelines nested `disk/` `flake/` `classic/` `nix/` `verify/` + `nixcfg/` |
| `actions/` | One `setup.sh` per action (not a logic/ui split) |
| `scripts/` | Scripts copied onto the installed machine (`tc-*` / `nds-*`) |
| `tests/` | Cross-feature runner only — suites live under features |

Feature folders use `logic/` + `ui/` (+ colocated `tests/`). Actions are a single `setup.sh`. Pure **data** under `data/` is not auto-sourced.

`nds_app_bootstrap` in `main.sh` is the only early load list. After an action is imported, `nds_app_prepareAction` loads settingsManager, then git / bundle / install.

App function names: `nds_app_<feature>_<layer>_<camelAction>` for actionHandler. Domain features keep `nds_git_*` / `nds_install_*`. Settings store keeps `nds_cfg_*`.
