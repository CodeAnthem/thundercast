# bashTestSuite

[![bashTestSuite selftest](https://github.com/CodeAnthem/thundercast/actions/workflows/bashTestSuite-selftest.yml/badge.svg)](https://github.com/CodeAnthem/thundercast/actions/workflows/bashTestSuite-selftest.yml)
[![bashTestSuite shellcheck](https://github.com/CodeAnthem/thundercast/actions/workflows/bashTestSuite-shellcheck.yml/badge.svg)](https://github.com/CodeAnthem/thundercast/actions/workflows/bashTestSuite-shellcheck.yml)

Run Bash `*_TEST.sh` files one process at a time: count pass/fail, write failures to a log.

![uses none](https://img.shields.io/badge/uses-none-lightgrey?style=flat-square) ![subshells yes](https://img.shields.io/badge/subshells-yes-d73a49?style=flat-square)

## Use

A test file is `*_TEST.sh` next to the feature. It defines `suite_<name>()`. The runner sources the file and calls every new function whose name starts with `suite_`. `<name>` is a label in the fail log.

Each file runs in a new bash. Load fixtures from the test (`source` a known setup). `setup_TEST.sh` is never collected as a test when you pass a directory.

Record with `bts_pass` / `bts_fail`. Labels name the **contract**; a fail label includes the unexpected value. `bts_section` only when that group has two or more cases.

Anything the child prints that is not a suite line (`[OK]`, `[FAIL]`, `[DEBUG]`, section) is a **leak** and fails the run. Swallow expected product stderr (`2>/dev/null`) with a one-line comment of the message. `>> /dev/null` does not hide logger lines.

### API

| Call | Arguments | Effect |
|------|-----------|--------|
| `bts` | `[-f] [--log PATH] [--selftest] [--debug] [PATH ...]` | Run tests; quiet one status line, `-f` case list |
| `bts_pass` | `<label>` | Increment passed; print the case if `-f` |
| `bts_fail` | `<label>` | Increment failed; print if `-f`; append the label to the fail log |
| `bts_section` | `<title>` | Group header (`-f` only) |
| `assert_contains` | `<haystack> <needle> [label]` | Pass or fail on substring |
| `assert_not_contains` | `<haystack> <needle> [label]` | Pass or fail on missing substring |

### Examples

```bash
source "$(dirname "${BASH_SOURCE[0]}")/../setup_TEST.sh"

suite_lookup() {
    bts_section "Lookup"
    got=${ feature_get a; }
    if [[ "$got" == "1" ]]; then
        bts_pass "known key returns the value"
    else
        bts_fail "known key was '${got}'"
    fi
    rc=0
    feature_get missing 2>/dev/null || rc=$?  # unknown key
    if [[ "$rc" -ne 0 ]]; then
        bts_pass "unknown key fails"
    else
        bts_fail "unknown key succeeded"
    fi
}
```

### Run

```bash
bash utilities/bashTestSuite/main.sh path/to/feature_TEST.sh
bash utilities/bashTestSuite/dev/selftest.sh
bash utilities/bashTestSuite/dev/shellcheck.sh
```

Quiet is the default. On failure, stderr is `FAIL <n> <path>` — read that log. `-f` prints each case.

| Flag | Meaning |
|------|---------|
| `-f` / `--format` | Print each case |
| `--selftest` | Run `tests/` (no PATH) |
| `--log PATH` | Fail log (default `$PWD/.bashTestSuite.fail.log`) |
| `--debug` | Suite debug logs |

`NO_COLOR` disables color. `BTS_COLOR=1` forces it. Quiet status is never colored.

| Exit | stderr | Fail log |
|------|--------|----------|
| 0 | `OK` | deleted |
| 1 | `FAIL <n> <path>` | issues only |
| 2 | usage / bad path | none |

## Design

Quiet so a pass is one word. Isolate per file so a crash cannot poison the next file. Leftover child output is a fail, not decoration. Color tokens are set once at init. The isolate child inherits `BTS_COLOR` because its stderr is a capture file. `stty` is saved before the run and restored after every file — tests that talk to `/dev/tty` must not leave the console broken.

## Develop

| File | Role |
|------|------|
| `main.sh` | Sole loader and CLI. Declares `bts_config`, sources children, inits ui/logger, public `bts` |
| `logger.sh` | `bts_debug` / `info` / `warn` / `error` / `fatal` / `bts_status`. Init: `_bts_logger_init` |
| `ui.sh` | Color tokens, section, case lines, `_bts_summary`. Init: `_bts_ui_init` |
| `assert.sh` | `bts_pass` / `bts_fail` / substring asserts |
| `discover.sh` | Collect `*_TEST.sh` (skip `setup_TEST.sh` on a dir walk) |
| `execute.sh` | Source one file; run new `suite_*` |
| `isolate.sh` | Child bash per file, leaks, TTY restore, fail log, `CRASH` |

`bts_config` is the only state map. Do not pass its name around.

Child: `BTS_CHILD_FILE` set, `bash main.sh` with no argv. Planned finish writes `clean=1` in the counts file. Missing counts, or a non-zero exit without `clean=1`, is `CRASH` — recorded pass/fail are kept and `CRASH` is still appended. Child env: `BTS_FORMAT`, `BTS_DEBUG`, `BTS_FAIL_LOG`, `BTS_CURRENT_FILE`, `BTS_COUNTS_FILE`, `BTS_COLOR`. Parent prepends `failed= passed= files=` on failure.

Intentional subshells: `$(cd …)` / `$(find …)` for paths; isolate child. Do not fold the isolate child into the parent process.

Do not:

- Source a product from this suite
- Treat `setup_TEST.sh` as a discovered test
- `source` child count files into variables named `passed` / `failed` (nameref clash)
- Pass a config array name into inits
- Expose a second run API (`bts_sourceTree`, `bts_runSuite`, `bts_result`)

### Tests

`tests/run_TEST.sh` — `bash utilities/bashTestSuite/dev/selftest.sh`
