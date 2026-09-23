# Task

In-progress line, spinner, OK/FAIL. Vacates the CR line on `ui.line.take`. Does not prompt.

[![uses eventBus](https://img.shields.io/badge/uses-eventBus-2ea44f?style=flat-square)](../eventBus/README.md)
[![uses logger](https://img.shields.io/badge/uses-logger-2ea44f?style=flat-square)](../logger/README.md)
![subshells yes](https://img.shields.io/badge/subshells-yes-d73a49?style=flat-square)

## Use

Call after essentials has loaded (after ui). Bootstrap lives in the [parent README](../README.md). Close every start with `taskOk`, `taskFail`, or `taskCancel` before `ui_section`.

INT: `trapRegister INT taskOnInt`. That cancels the line and exits 130. EXIT restores the TTY.

### API

| Call | Arguments | Effect |
|------|-----------|--------|
| `taskStart` | `<label>` | In-progress `[   ]` line |
| `taskSpin` | `<label>` | Start + background spinner (parent kills on INT) |
| `taskWatch` | `<pid>` `[label]` | Foreground spinner until pid exits |
| `taskOk` / `taskFail` | `[label]` | `[OK]` / `[FAIL]` with elapsed seconds |
| `taskCancel` | — | Drop the line, no OK/FAIL |
| `taskYield` / `taskResume` | — | Let other TTY output through; redraw |
| `taskOnInt` | — | Cancel, newline, exit 130 |

### Examples

```bash
trapRegister INT taskOnInt
taskSpin "Format"
# work in this shell
taskOk
```

## Design

- Hooks `ui.line.take` → `taskYield` (name stays). Hooks `ui.section.begin` → fail-if-open then fatal. Hooks `trap.INT` → `taskOnInt`.
- Prompt must not call this API. It only `eventRun ui.line.take`.
- No resume after prompt. Yield is vacate, not pause/resume around a question.

## Develop

Init in `task.sh`: globals, then the three `eventRegister`s. ui events may already exist.

Chrome uses `__UI_INDENT_B` and `__UI_COLOR`. Globals that must stay: `__TASK_NAME` / `__TASK_START` / `__TASK_SPIN_PID` / `__TASK_WANT_SPIN`.

Intentional subshell: background spinner `( )` child. `_taskKillPidTree` must tolerate empty `/proc/.../children` under `set -e`.

Do not:

- Call `ui_section` while a task is open
- `eventRun` from a hook
- Resume automatically after `ui.line.take`

### Tests

`task_TEST.sh` — `bash utilities/bashTestSuite/main.sh utilities/essentials/task/task_TEST.sh`. TTY walk: `bash utilities/essentials/task/task_DEMO.sh`.
