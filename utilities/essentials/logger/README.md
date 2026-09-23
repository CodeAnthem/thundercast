# Logger

Leveled console, scoped log files, and a compose file that merges several scopes.

![uses none](https://img.shields.io/badge/uses-none-lightgrey?style=flat-square)
![subshells no](https://img.shields.io/badge/subshells-no-2ea44f?style=flat-square)

## Use

Call after essentials has loaded. Bootstrap lives in the [parent README](../README.md).

A **scope** is a named log file under `LOG_ROOT`. `logger_scopeCreate` makes it current. Later `info` / `warn` / … with the default destination write there. Switch with `logger_scopeSet`. One scope per workstream. Every file write also appends to `all`.

**Compose** is a separate file. `logger_composeWrite` appends a raw line there. `logger_compose` copies several scope files into it as titled sections (unknown names are skipped). `logger_composeRead` prints that file.

### Config

Keys this feature reads from `essentials_config` (defaults from source). Map is filled in the [parent README](../README.md).

| Key | Default | Meaning |
|-----|---------|---------|
| `LOG_ROOT` | `/tmp/logs` | Directory for scope files |
| `LOG_PURGE` | `false` | Any value other than `false` deletes `*.log` there on init, when the directory already exists |
| `LOG_MINLEVEL` | `info` | Lowest severity that still writes. `error` and `fatal` always write |
| `LOG_STDERRLEVEL` | `warn` | This severity and higher go to stderr; lower go to stdout |
| `LOG_INDENT` | `0` | Spaces prepended to console labels. Fixed at init |
| `LOG_COLOR` | `true` | Color console labels. Also a global, read on each line |
| `LOG_COMPOSE_FILENAME` | `compose.log` | Compose filename |

Severities, high to low: `fatal` `error` `warn` `info` `debug` `verbose`. `log` is not a severity.

### API

| Call | Arguments | Effect |
|------|-----------|--------|
| `verbose` `debug` `info` `warn` `error` `log` | `<message>` `[destination]` `[scope]` | Write. `destination`: `console` \| `file` \| `both` (default `both`). Quiet writers are nops. `log` is never quiet and has no label |
| `fatal` | `<message>` `[exit_code]` | Log, then `exit` (default `1`). EXIT traps still run |
| `logger_setMinLevel` | `<level>` | Rebuild the quiet map and rebind writers |
| `logger_isLevel` | `<level>` | True if `<level>` is a severity |
| `logger_scopeCreate` | `<title>` `<scope>` `[filename]` | Create a file under `LOG_ROOT` and make it current. Default filename `<scope>.log`. Fails if the scope exists |
| `logger_scopeSet` | `<scope>` | Make an existing scope current |
| `logger_scopeGetCurrent` | — | Print the current scope name |
| `logger_scopeGetPath` | `[scope]` | Print the file path (default: current) |
| `logger_scopeGetTitle` | `[scope]` | Print the title (default: current) |
| `logger_scopeExists` | `<scope>` | Silent true/false. Name must already be sanitized |
| `logger_scopeRead` | `<scope>` `[lines]` | `0` or omit: all. `>0`: `head`. `<0`: `tail` |
| `logger_composeWrite` | `<message>` | Raw line into the compose file (no console) |
| `logger_compose` | `<title>` `<scope>`… | Append those scopes as titled sections. First call also writes a banner. Unknown names are skipped |
| `logger_composeRead` | `[lines]` | Read the compose file (`logger_scopeRead` rules) |
| `logger_markError` | — | Increment the error counter |
| `logger_markWarn` | — | Increment the warn counter |
| `logger_hasError` | — | True if the error counter is > 0 |
| `logger_hasWarn` | — | True if the warn counter is > 0 |
| `logger_resetCounts` | — | Zero both counters |

### Examples

```bash
logger_scopeCreate "Disk" "disk"
info "partitioned"
logger_scopeCreate "Nix" "nix"
info "built"
logger_composeWrite "operator: used default swap"
logger_compose "Install" "disk" "nix"
logger_composeRead
```

## Design

Quiet levels are rebound to nops. `logger_setMinLevel` rebuilds that binding. `error` and `fatal` are never quiet. `error` / `fatal` increment the error counter; `warn` increments the warn counter. Quiet writers do not count. `logger_markError` / `logger_markWarn` count without writing.

Console lines are labeled. File lines get a timestamp. `log` writes the message only. Scope names and filenames are lowercased and sanitized to `[a-z0-9._-]`.

## Develop

Init in `logger.sh`: counts → output (maps, bind writers) → formatter (uses `__LOGGER_LEVELS`) → scopes (`all`) → compose (`internal_compose`, which `logger_scopeCreate` leaves current). Each `*_init` is unset after it runs. `essentials.sh` then creates `internal_essentials`, so a normal load’s current scope is that, not `internal_compose`. `logger_setMinLevel` re-`eval`s `verbose`/`debug`/…; `fatal` is never a nop.

No calls to scriptInfo, eventBus, or bashVersion. Syntax here is nameref and `${var,,}` (Bash 4.3) plus `printf` time stamps (4.2). Nothing is 5.3-only. The loader still sources bashVersion first so a configured minimum fails before this file is parsed.

Globals that must stay: `__LOGGER_LEVELS` / `__LOGGER_LEVEL_SET`, quiet + stderr maps, `__LOGGER_SCOPE_{CURRENT,TITLES,PATHS,ROOT,ALL_PATH}`, `__LOGGER_ERROR_COUNT` / `__LOGGER_WARN_COUNT`, `LOG_COLOR`. File writes use `ALL_PATH`.

No subshells. The compose append is a `{ …; } >> file` group.

Do not:

- Put `log` in `__LOGGER_LEVELS`
- Recreate scopes `all` or `internal_compose`
- Redeclare `info` / `warn` / … after load (the binding is the quiet switch)
- Log while the current scope is `all` (scope path and `ALL_PATH` are the same file, so the line is written twice)
- Treat a missing name in `logger_compose` as an error

Files: `logger.sh` init; `logger_counts.sh` counters; `logger_output.sh` maps, writers, `logger_setMinLevel` / `logger_isLevel`; `logger_formatter.sh` labels; `logger_scopes.sh` files; `logger_compose.sh` merge.

### Tests

`logger_TEST.sh` — `bash utilities/bashTestSuite/main.sh utilities/essentials/logger/logger_TEST.sh`.
