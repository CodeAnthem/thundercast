# ThunderCast — project map

Monorepo: `nds/` · `tcast/` · `fleet/` · shared `utilities/`

| Product | Maturity | Bash | VERSION | Tests |
|---------|----------|------|---------|--------|
| NDS | wip | 5.3+ | `nds/VERSION` | `bash nds/dev/selftest.sh` · `bash nds/dev/shellcheck.sh` |
| tcast | wip | 5.3+ | `tcast/VERSION` | `bash tcast/dev/selftest.sh` · `bash tcast/dev/shellcheck.sh` |
| fleet toolkit | wip | portable unless noted | `fleet/toolkit/VERSION` | `bash fleet/dev/selftest.sh` · `bash fleet/dev/shellcheck.sh` |

| Item | Path |
|------|------|
| Shared bash tests | `utilities/bashTestSuite` (`*_TEST.sh` beside features) |
| ShellCheck helper | `.github/scripts/shellcheck-lib.sh` (lint install — not a test runner) |
| Trust / curl entry | `docs/TRUST.md` · `nds/start.sh` |
| NDS src conventions | `nds/docs/src-conventions.md` |
| Scratch | `<product>/.wip/` (local; ISO matrix in `nds/.wip/TESTING.md`) |

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
| `utilities/bashTestSuite` | Shared bash test framework |
