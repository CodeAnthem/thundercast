# NDS tests

Cross-feature runner only. Feature suites live next to the code they cover.

```
src/tests/
  run.sh           # bootstrap + load features + source colocated suites
  framework.sh     # assert helpers, suite runner
  fixtures/        # shared fixtures (e.g. remote preset)
```

Feature suites: `src/app/tests/`, `src/app/settingsManager/tests/` (including `settings_sm_suite_test.sh`), `src/app/bundle/tests/`, `src/git/tests/`, `src/install/tests/`, `src/tools/tests/`.

Toolkit (separate process): `toolkitScripts/tests/run.sh`.

## Run

```bash
bash dev/selftest.sh          # CI gate
bash src/tests/run.sh         # same suite, direct
bash dev/shellcheck.sh
bash toolkitScripts/tests/run.sh
# or NDS_TEST=true and pick the `test` action
```

Interactive prompt walk (`uiSmoke`) and real VM installs are not commit gates. Operator cases: [docs/testing.md](../../docs/testing.md).
