# Trap Bridge

Turns bash traps into events. Does not alias `trap`.

[![uses eventBus](https://img.shields.io/badge/uses-eventBus-2ea44f?style=flat-square)](../eventBus/README.md)
[![uses logger](https://img.shields.io/badge/uses-logger-2ea44f?style=flat-square)](../logger/README.md)
![subshells no](https://img.shields.io/badge/subshells-no-2ea44f?style=flat-square)

## Use

Call after essentials has loaded. Bootstrap lives in the [parent README](../README.md).

`trapRegister INT fn` creates event `trap.INT`, registers `fn`, and installs one dispatcher for INT. The hook’s `$1` is `$?` from when the trap fired. The last `trapUnregister` restores the previous trap (or the default). A later raw `trap` still last-wins.

Presets add EXIT lifecycle events. They do not install INT or TERM.

### Config

| Key | Default | Meaning |
|-----|---------|---------|
| `TRAP_PRESETS` | `false` | `true` creates `exit` / `exitError` / `exitClean` and keeps an EXIT trap |

Map is filled in the [parent README](../README.md).

### API

| Call | Arguments | Effect |
|------|-----------|--------|
| `trapRegister` | `<signal>` `<func>` `[priority]` | Map to `trap.<SIGNAL>`, `eventRegister`, install the dispatcher. Default priority `50`. Hook `$1` is the status |
| `trapUnregister` | `<signal>` `<func>` | Remove that hook. Restore the previous trap when none remain |

Signals: `INT`/`SIGINT`, `TERM`/`SIGTERM`, `EXIT`, or any name `trap` accepts. A `SIG` prefix is stripped.

When presets are on, register with `eventRegister`, not `trapRegister EXIT`:

| Event | When | `$1` |
|-------|------|------|
| `exit` | Always on EXIT | process exit code |
| `exitError` | `logger_hasError` or exit code ≠ 0 | process exit code |
| `exitClean` | no logger errors and exit code = 0 | process exit code |

### Examples

```bash
onInt() { warn "interrupted"; exit 130; }
trapRegister INT onInt 10

onExit() { rm -f "${TMPFILE:-}"; }
eventRegister exit onExit 50
```

A signal hook replaces the default disposition. `exit` from the hook if the process should die.

## Design

Event names are `trap.INT`, `trap.TERM`, `trap.EXIT`. On install, a pre-existing handler is stored and run after `eventRun`. Hook failures are ignored (`eventRun … || true`). The EXIT trap returns 0 so it does not replace the process status. Presets decide `exitError` / `exitClean` with `logger_hasError`, not with event state.

## Develop

Init in `trapBridge.sh` always sources the bridge. `trapBridge_presets.sh` loads only when `TRAP_PRESETS` is `true`. Presets set `__TH_KEEP_EXIT` and install EXIT even with zero `trap.EXIT` hooks.

Globals that must stay: `__TH_INSTALLED`, `__TH_PREV`, `__TRAP_LAST_EXIT_CODE`, `__TH_KEEP_EXIT` (presets). `_essentials_trapBridge_onPresetExit` is a stub in the bridge; presets replace it. The signal event is `trap.${signal}`.

No subshells. `trap -p` and the hook count are captured with `${ …; }`.

Do not:

- Alias or wrap `trap`
- Pre-install INT or TERM
- Uninstall EXIT while presets are on (`__TH_KEEP_EXIT`)
- Put log counters in this feature

Files: `trapBridge.sh` init; `trapBridge_dispatch.sh` register/dispatch; `trapBridge_presets.sh` EXIT events.

### Tests

`trapBridge_TEST.sh` — `bash utilities/bashTestSuite/main.sh utilities/essentials/trapBridge/trapBridge_TEST.sh`.
