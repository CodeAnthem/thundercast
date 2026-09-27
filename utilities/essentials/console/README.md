# Console

Prints one finished line on the console, and steps aside when a task owns the current line.

[![uses logger](https://img.shields.io/badge/uses-logger-2ea44f?style=flat-square)](../logger/README.md)
[![uses task](https://img.shields.io/badge/uses-task-2ea44f?style=flat-square)](../task/README.md)
![subshells no](https://img.shields.io/badge/subshells-no-2ea44f?style=flat-square)

## Use

Pass one string. If a task line is open, that line is cleared, this line is printed with a newline, and the task line is drawn again. If no task is open, or `taskYield` is not defined, the line is printed and that is all. Returns 0.

Levels, colour, and log files stay in the logger. A caller that wants both calls both. Bootstrap lives in the [parent README](../README.md).

### Config

| Key | Default | Meaning |
|-----|---------|---------|
| `CONSOLE_STREAM` | `stderr` | `stdout` or `stderr`. Where `console_write` prints. Read once, at init. |

### API

| Call | Arguments | Effect |
|------|-----------|--------|
| `console_write` | `<line>` | Prints `<line>` and a newline on `CONSOLE_STREAM` |

### Examples

```bash
taskStart "Disk"
console_write "partition table rewritten"
taskOk "Disk"
```

## Design

- Ask `taskIsOpen` when printing. Do not yield during init.
- This feature does not read task state. `taskIsOpen` is the query.

## Develop

`console.sh` is the entry: resolve `CONSOLE_STREAM`, mark init, then `console_write`.

Init checks the `console` done-token, copies `CONSOLE_STREAM` into `__CONSOLE_STREAM`, then marks. A rejected value returns before the mark. The global that must stay is `__CONSOLE_STREAM`.

Do not:

- Read `__TASK_*`
- Call `taskYield` from init
- Add a level, a colour, or a log file

### Tests

`console_TEST.sh` — `bash utilities/bashTestSuite/main.sh utilities/essentials/console/console_TEST.sh`
