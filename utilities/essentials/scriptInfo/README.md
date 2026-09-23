# Script Info

Script directory, name, and version for the running program.

![uses none](https://img.shields.io/badge/uses-none-lightgrey?style=flat-square)
![subshells no](https://img.shields.io/badge/subshells-no-2ea44f?style=flat-square)

## Use

Call after essentials has loaded. Bootstrap lives in the [parent README](../README.md). Capture getters with `${ scriptInfo_get_name; }`.

### Config

Keys this feature reads from `essentials_config`. All three are required; source has no defaults. Map is filled in the [parent README](../README.md).

| Key | Default | Meaning |
|-----|---------|---------|
| `SCRIPTINFO_DIR` | — | Script / source directory |
| `SCRIPTINFO_NAME` | — | Display name |
| `SCRIPTINFO_VERSION` | — | Version string |

A missing key exits 1 with `[ERROR] - [ScriptInfo] - <KEY> is required` on stderr.

### API

| Call | Arguments | Effect |
|------|-----------|--------|
| `scriptInfo_get` | — | Print every `key: value` pair |
| `scriptInfo_get_name` | — | Print the name |
| `scriptInfo_get_version` | — | Print the version |
| `scriptInfo_get_dir` | — | Print the directory |

### Examples

```bash
name=${ scriptInfo_get_name; }
dir=${ scriptInfo_get_dir; }
```

## Develop

Init copies the three keys into `__ESSENTIALS_SCRIPTINFO` (`script_dir` / `script_name` / `script_version`) and sets `__SCRIPTINFO_INITIALIZED`. Reads use `${config[KEY]:-}` so `set -u` still hits the empty checks. Errors are `echo`, not `fatal`.

No subshells.

Do not:

- Route missing-key errors through logger (they `echo` and `exit 1`)
- Recreate `__ESSENTIALS_SCRIPTINFO` or rename its keys
- Depend on `scriptInfo_get` order (associative-array order)

File: `scriptInfo.sh` — init and the four getters.

### Tests

`scriptInfo_TEST.sh` — `bash utilities/bashTestSuite/main.sh utilities/essentials/scriptInfo/scriptInfo_TEST.sh`.
