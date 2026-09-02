# bashTestSuite

Shared, product-agnostic bash test framework for ThunderCast.

## Layout

| File | Role |
|------|------|
| `main.sh` | Source tree of `*_TEST.sh`, run suites |
| `ui.sh` | Minimal pass/fail/section/summary output |
| `assert.sh` | Assertions (`assert_contains`, `assert_valid`, …) |

## Product entry

Each product’s `dev/selftest.sh` should:

1. `source utilities/bashTestSuite/main.sh`
2. Bootstrap the product under test
3. `bashTestSuite_sourceTree <product-src>`
4. Run `suite_*` functions (ordered list or `bashTestSuite_runAllSuites`)

## Conventions

- Test files end with **`_TEST.sh`** (importer skip + editor highlight)
- Live next to the feature they cover (optional `tests/` subdir is fine)
- Suite entry: `suite_<name>() { … }`
- No dependency on NDS `ui/` or `logger/` — suite has its own tiny UI

ShellCheck install/resolve stays in `.github/scripts/shellcheck-lib.sh` (different concern).
