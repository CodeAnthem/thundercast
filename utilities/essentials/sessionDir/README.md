# Session Dir

Per-session scratch directory with named subdirs. Purge is explicit.

[![uses logger](https://img.shields.io/badge/uses-logger-2ea44f?style=flat-square)](../logger/README.md)
![subshells no](https://img.shields.io/badge/subshells-no-2ea44f?style=flat-square)

## Use

Call after essentials has loaded. Bootstrap lives in the [parent README](../README.md).

Init creates `${RUNTIME_BASE}/${RUNTIME_PREFIX}_${timestamp}_$$` (mode `RUNTIME_MODE`) and any `RUNTIME_SUBDIRS`. Later calls can add more. Capture paths with `${ runtime_getDir; }`.

This feature does not register events. Hook `runtime_purge` / `runtime_purgeAll` from `exitClean` / `exitError` in the caller.

### Config

Keys this feature reads from `essentials_config` (defaults from source). Map is filled in the [parent README](../README.md).

| Key | Default | Meaning |
|-----|---------|---------|
| `RUNTIME_BASE` | `${TMPDIR:-/tmp}` | Parent directory. Must be writable by this user |
| `RUNTIME_PREFIX` | `essentials` | Directory-name prefix |
| `RUNTIME_SUBDIRS` | empty | Space-separated subdirs created on init |
| `RUNTIME_MODE` | `700` | `chmod` for the session dir and subdirs (octal) |
| `RUNTIME_PURGE_STALE` | `false` | `true` deletes `${base}/${prefix}_*` before creating this session |

Names are lowercased and sanitized to `[a-z0-9._-]`.

### API

| Call | Arguments | Effect |
|------|-----------|--------|
| `runtime_getDir` | — | Print the session directory |
| `runtime_getPath` | `<name>` | Print a tracked subdir path |
| `runtime_hasSubdir` | `<name>` | True if that name is tracked |
| `runtime_subdirCreate` | `<name>` | Create and track a subdir. Empty or duplicate name fails |
| `runtime_purge` | `<name>`… | Remove those tracked subdirs. Unknown names are skipped. Stops on the first `rm` failure; that name stays tracked. The session dir stays. No names is an error |
| `runtime_purgeAll` | — | Remove the session directory and drop every tracked name |

### Examples

```bash
runtime_subdirCreate work
onClean() { runtime_purgeAll; }
onFail() { runtime_purge config work; }
eventRegister exitClean onClean 90
eventRegister exitError onFail 90
```

## Design

One directory per process. A later process does not see this session’s `secrets` unless the caller looks them up. `mkdir` / `chmod` run as the current user; failure is `fatal`. Stale purge is only `${prefix}_*` under `RUNTIME_BASE`. No `trap` and no `eventRegister` in this feature.

## Develop

Init uses `info` / `warn` / `fatal`. Tracks `__RUNTIME_DIR`, `__RUNTIME_SUBDIRS`, `__RUNTIME_MODE`.

No subshells. The nullglob save/restore is `${ shopt -p nullglob; }`.

Do not:

- `eventRegister` or install a trap from this feature
- Recreate `__RUNTIME_SUBDIRS` keys by hand
- Leave `nullglob` on (stale purge saves and restores it)

File: `sessionDir.sh` — init and the public calls.

### Tests

`sessionDir_TEST.sh` — `bash utilities/bashTestSuite/main.sh utilities/essentials/sessionDir/sessionDir_TEST.sh`.
