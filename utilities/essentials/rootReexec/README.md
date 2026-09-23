# Root Reexec

Re-exec this process as root via `sudo` when configured.

[![uses logger](https://img.shields.io/badge/uses-logger-2ea44f?style=flat-square)](../logger/README.md)
![subshells no](https://img.shields.io/badge/subshells-no-2ea44f?style=flat-square)

## Use

No public function. On source: if `EUID` is 0, or `ROOTREEXEC_ROOT` is not `true`, init returns. Otherwise it `exec`s `sudo` and does not return. Bootstrap lives in the [parent README](../README.md).

### Config

Keys this feature reads from `essentials_config` (defaults from source). Map is filled in the [parent README](../README.md).

| Key | Default | Meaning |
|-----|---------|---------|
| `ROOTREEXEC_ROOT` | `false` | `true` enables the re-exec |
| `ROOTREEXEC_SCRIPT` | — | Path to re-exec. Required when the re-exec runs |
| `ROOTREEXEC_PURPOSE` | empty | Extra text in the “Root required” message |
| `ROOTREEXEC_KEEP_ENV_PREFIX` | empty | Identifier prefix; matching variables are passed as `sudo VAR=value` |
| `ROOTREEXEC_KEEP_ENV_VARS` | empty | Space-separated names passed the same way |

Prefix must match `^[A-Za-z_][A-Za-z0-9_]*$`. Unset named vars are skipped.

### Examples

```bash
essentials_config[ROOTREEXEC_ROOT]=true
essentials_config[ROOTREEXEC_SCRIPT]="$0"
essentials_config[ROOTREEXEC_KEEP_ENV_PREFIX]=APP_
```

## Design

`sudo VAR=value bash "$script" args…` — sudo’s assignment form, not `--preserve-env`. `exec` replaces the process.

## Develop

Init namerefs `essentials_config`. On the sudo path it namerefs `originalArgs`, a local of `_essentials_loadModules`, so this init has to run inside that call. Uses `debug` / `info` / `fatal`. The loader sources this immediately after logger. `exec` replaces the process, so features below run only in the final process.

Globals that must stay: `__ROOTREEXEC_INITIALIZED`. `_essentials_rootReexec_collectEnv` takes the destination array name as `$1`. Empty keep lists omit the `sudo VAR=value` args.

No subshells. The prefix walk is `eval` in this shell.

Do not:

- Source this feature before logger
- Read `originalArgs` after `_essentials_loadModules` returns
- Treat `_essentials_rootReexec_collectEnv` as API

File: `rootReexec.sh` — init, env collect, `exec sudo`.

### Tests

`rootReexec_TEST.sh` — `bash utilities/bashTestSuite/main.sh utilities/essentials/rootReexec/rootReexec_TEST.sh`.
