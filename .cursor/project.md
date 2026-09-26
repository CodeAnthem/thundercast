# ThunderCast — project map

Monorepo: `nds/` · `tcast/` · `fleet/` · `utilities/bashTestSuite` · `utilities/essentials`

| Product | Maturity | Bash | VERSION | Tests |
|---------|----------|------|---------|--------|
| bashTestSuite | wip | 4.3+ | `utilities/bashTestSuite/VERSION` | `bash utilities/bashTestSuite/dev/selftest.sh` · `bash utilities/bashTestSuite/dev/shellcheck.sh` |
| essentials | wip | 5.3+ | `utilities/essentials/VERSION` | `bash utilities/essentials/dev/selftest.sh` · `bash utilities/essentials/dev/shellcheck.sh` |
| NDS | wip | 5.3+ | `nds/src/VERSION` | `bash nds/dev/selftest.sh` · `bash nds/dev/shellcheck.sh` |
| tcast | wip | 5.3+ | `tcast/VERSION` | `bash tcast/dev/selftest.sh` · `bash tcast/dev/shellcheck.sh` |
| fleet toolkit | wip | portable unless noted | `fleet/toolkit/VERSION` | `bash fleet/dev/selftest.sh` · `bash fleet/dev/shellcheck.sh` |

| Item | Path |
|------|------|
| ShellCheck helper | `.github/scripts/shellcheck-lib.sh` (lint install — not a test runner) |
| Trust / curl entry | `docs/TRUST.md` · `nds/start.sh` |
| NDS layout | this file, section "NDS layout" |
| Scratch | `<product>/.wip/` (local; ISO matrix in `nds/.wip/TESTING.md`) |

NDS loads essentials from `nds/src/app/main.sh`. `nds/dev/selftest.sh` runs the NDS and fleet action suites only.

## NDS layout

Essentials (`utilities/essentials`) is a general-purpose Bash toolkit: logger, UI, importer, events, prompts, session directory, traps. Do not add NDS-specific behavior to it. NDS-only behavior lives in `nds/src`. If this section disagrees with the user, stop and ask which one to update.

```
nds/src/
  app/main.sh                entry: essentials, CLI, then nds_pipeline_run
  VERSION
  setup_TEST.sh              shared test boot; provides nds_test_session
  lib/                       lib_bool.sh, lib_rand.sh
  app/                       framework, no install knowledge
    features.sh              load order: session, utility, action, recipe, recipe/schema, cook, wizard, wizard/askers, wizard/git
    session/                 cli, mode, skip, dirs, exit, failure, install logs
    utility/utility.sh       nds_requireUtility, nds_utility_addRoot
    action/                  discover, store, check, UI
    pipeline.sh              nds_pipeline_run, nds_pipeline_recipe
    confirm.sh               summary, wipe warning, yes/no
    finish.sh                bundle hints, USB key hints, reboot question
  recipe/                    the contract. No UI. No tools.
  wizard/                    interactive driver. ask.sh, askers/, git/
  cook/                      birth from one sealed file. No TTY.
  utilities/<name>/main.sh   tools
  actions/<name>/setup.sh    builtin recipe makers
fleet/nds-actions/<name>/setup.sh
  logic/                     that action's cook helpers
```

| Path | Role |
|------|------|
| `utilities/essentials` | Shared Bash runtime. Own product. |
| `utilities/bashTestSuite` | Shared test runner. Own product. |
