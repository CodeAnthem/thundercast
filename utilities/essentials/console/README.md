# Console

Prints one finished line on stdout or stderr, and steps aside when a task owns the current line.

[![uses task](https://img.shields.io/badge/uses-task-2ea44f?style=flat-square)](../task/README.md)
![subshells no](https://img.shields.io/badge/subshells-no-2ea44f?style=flat-square)

## Use

Pass one string. If a task line is open, that line is cleared, this line is printed with a newline, and the task line is drawn again. Stderr always does this. Stdout does it only when stdout is a terminal. If no task is open, or `taskYield` is not defined, the line is printed and that is all. Returns 0.

Levels, colour, and log files stay in the logger. Bootstrap lives in the [parent README](../README.md).

### API

| Call | Arguments | Effect |
|------|-----------|--------|
| `console_writeErr` | `<line>` | Prints `<line>` and a newline on stderr |
| `console_writeOut` | `<line>` | Prints `<line>` and a newline on stdout |

### Examples

```bash
taskStart "Disk"
console_writeErr "partition table rewritten"
taskOk "Disk"
```

## Design

- Ask `taskIsOpen` when printing. Do not yield during init.
- Stdout skips the yield when it is not a terminal. A redirected stdout does not share the cursor the task line is on.
- This feature does not read task state. `taskIsOpen` is the query.

## Develop

`console.sh` is the entry: mark init, then `console_writeErr` and `console_writeOut`. Both call `_essentials_console_emit`.

Init checks the `console` done-token and marks it. No config keys and no globals.

Do not:

- Read `__TASK_*`
- Call `taskYield` from init
- Add a level, a colour, or a log file

### Tests

`console_TEST.sh` — `bash utilities/bashTestSuite/main.sh utilities/essentials/console/console_TEST.sh`
