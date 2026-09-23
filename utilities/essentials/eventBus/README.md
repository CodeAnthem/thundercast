# Event Bus

Named events with priority-ordered hooks.

![uses none](https://img.shields.io/badge/uses-none-lightgrey?style=flat-square)
![subshells no](https://img.shields.io/badge/subshells-no-2ea44f?style=flat-square)

## Use

Call after essentials has loaded. Bootstrap lives in the [parent README](../README.md). Signal traps are [trapBridge](../trapBridge/README.md).

Lower priority runs first. Same priority keeps registration order. A second `eventRegister` of the same `(name, func)` is a no-op. `return 1` is a failure, not “handled”.

### API

| Call | Arguments | Effect |
|------|-----------|--------|
| `eventCreate` | `<name>` | Create an event. Existing name stays |
| `eventHas` | `<name>` | True if the event exists |
| `eventHookCount` | `<name>` | Print the hook count. Capture with `${ eventHookCount "$name"; }` |
| `eventRegister` | `<name>` `<func>` `[priority]` | Add a hook. Default priority `50`. Creates the event if needed. `func` must already exist |
| `eventUnregister` | `<name>` `<func>` | Remove that hook. The event stays |
| `eventRun` | `<name>` `[args…]` | Run hooks. Args are `$1`… Unknown name returns 1. Zero hooks returns 0 |
| `eventStop` | — | Skip the remaining hooks for this run. Only valid inside a hook |

Event names: `[A-Za-z][A-Za-z0-9._:-]*`.

| Hook | `eventRun` |
|------|------------|
| return 0 | continue |
| return 0 after `eventStop` | skip the rest, return 0 |
| return non-zero | skip the rest, return that code |

Nested `eventRun` is rejected, except `exit` / `exitError` / `exitClean` (so an INT hook can `exit` and still run cleanup). One run after another is fine.

### Examples

```bash
onReady() { printf 'ready: %s\n' "$1"; }
onLate() { printf 'late\n'; }
eventRegister app.ready onReady 10
eventRegister app.ready onLate 50
eventRun app.ready "ok"
```

## Design

Hooks live in parallel arrays. Dispatch is `"$func" "$@" || rc=$?`, so `set -e` does not abort the run. Stop and dispatch flags reset once after the loop. This feature does not count errors or install traps.

## Develop

Init in `eventBus.sh` sources registry, then dispatch.

Globals that must stay: `__EH_EVENT` / `__EH_FUNC` / `__EH_PRIO` / `__EH_SEQ` / `__EH_SEQ_NEXT`, `__EH_CREATED`, `__EH_DEDUPE`, `__EVENT_DISPATCHING`, `__EVENT_STOP`.

No subshells. Hooks run in the dispatcher shell.

Do not:

- Capture these functions with `$(fn)` — use `${ fn args; }`
- Name locals so they collide with a caller nameref (prefix `_eh_`)
- Teach this feature about signals or log counts
- Treat return `1` as stop

Files: `eventBus.sh` init; `eventBus_registry.sh` create/register; `eventBus_dispatch.sh` `eventRun` / `eventStop`.

### Tests

`eventBus_TEST.sh` — `bash utilities/bashTestSuite/main.sh utilities/essentials/eventBus/eventBus_TEST.sh`.
