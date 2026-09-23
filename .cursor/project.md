# ThunderCast — project map

Monorepo: `nds/` · `tcast/` · `fleet/` · `utilities/bashTestSuite` · `utilities/essentials`

| Product | Maturity | Bash | VERSION | Tests |
|---------|----------|------|---------|--------|
| bashTestSuite | wip | 4.3+ | `utilities/bashTestSuite/VERSION` | `bash utilities/bashTestSuite/dev/selftest.sh` · `bash utilities/bashTestSuite/dev/shellcheck.sh` |
| essentials | wip | 5.3+ | `utilities/essentials/VERSION` | `bash utilities/essentials/dev/selftest.sh` · `bash utilities/essentials/dev/shellcheck.sh` |
| NDS | wip | 5.3+ | `nds/src/VERSION` | parked (nds mid-refactor) · `bash nds/dev/shellcheck.sh` |
| tcast | wip | 5.3+ | `tcast/VERSION` | `bash tcast/dev/selftest.sh` · `bash tcast/dev/shellcheck.sh` |
| fleet toolkit | wip | portable unless noted | `fleet/toolkit/VERSION` | `bash fleet/dev/selftest.sh` · `bash fleet/dev/shellcheck.sh` |

| Item | Path |
|------|------|
| ShellCheck helper | `.github/scripts/shellcheck-lib.sh` (lint install — not a test runner) |
| Trust / curl entry | `docs/TRUST.md` · `nds/start.sh` |
| NDS src conventions | `nds/docs/src-conventions.md` |
| Scratch | `<product>/.wip/` (local; ISO matrix in `nds/.wip/TESTING.md`) |

NDS loads essentials from `nds/src/app/main.sh`. Do not run essentials or bashTestSuite tests from `nds/dev/selftest.sh`.

## NDS layout

| Path | Role |
|------|------|
| `nds/src/logger` | Foundation logger (console + install log) |
| `nds/src/lib` `ui` | Shared helpers / interactive UI |
| `nds/src/app` | Backbone: moduleLoader, sessionControl, actionManager, utilityManager, settingsManager, bundleManager, ensure |
| `nds/src/utilities` | NDS-free `git` / `flake` / `qr` / `pkg` / `age` / `facter` |
| `nds/src/wizard/git` | Git IO + action-facing bridge |
| `nds/src/install` | disk / flake / classic / nix / verify |
| `nds/src/actions` | Core actions (no toolkit/addFleetHost) |
| `fleet/nds-actions` | Fleet birth wizards (auto-discovered) |
| `utilities/essentials` | Shared Bash runtime (own product) |
| `utilities/bashTestSuite` | Shared Bash test framework (own product) |
