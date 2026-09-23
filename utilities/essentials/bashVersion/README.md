# Bash Version

Check this Bash against a major and minor, and stop essentials when it is too old.

![uses none](https://img.shields.io/badge/uses-none-lightgrey?style=flat-square)
![subshells no](https://img.shields.io/badge/subshells-no-2ea44f?style=flat-square)

## Use

Bootstrap lives in the [parent README](../README.md). This feature loads first. Init passes `BASHVERSION_MAJOR` and `BASHVERSION_MINOR` to `bashVersion_check` and returns that result. A failure fails the source. Major `0` returns 0 before that call, so the check does not run.

Patch is ignored: `5.3.0` satisfies major `5`, minor `3`.

### Config

Keys this feature reads from `essentials_config`:

| Key | Default | Meaning |
|-----|---------|---------|
| `BASHVERSION_MAJOR` | `0` | Minimum major. `0` skips the check. Empty is the same as unset |
| `BASHVERSION_MINOR` | `3` | Minimum minor, used only when major is not `0`. Empty is the same as unset |

### API

| Call | Arguments | Effect |
|------|-----------|--------|
| `bashVersion_check` | `major` `minor` | Return 0 if this Bash is at least that major and minor. Otherwise print `[ERROR] - [BashVersion] - requires Bash <major>.<minor> or newer (found <version>).` on stderr and return 1 |

### Examples

```bash
bashVersion_check 5 3 || exit 1
```

## Design

- Major, then minor. A higher major passes even when its minor is smaller.

## Develop

`_essentials_bashVersion_init` runs at source, before every other feature. It namerefs `essentials_config`. Major defaults to `0`; `0` marks init and returns before `bashVersion_check`. Any other major is passed through with `BASHVERSION_MINOR` (or `3`), and init is marked only when that check returns 0. `bashVersion_check` stays callable. The file ends with `_essentials_bashVersion_init || return 1`.

Layout: `bashVersion.sh` — `bashVersion_check`, then init. The loader sources this file first.

Do not:

- Move this feature later in the loader
- Call logger from this feature (it is not loaded yet)
- Capture `bashVersion_check` with `$(fn)` — use `${ fn; }`
- Treat major `0` as "Bash 0.something"; init returns before `bashVersion_check`

### Tests

`bashVersion_TEST.sh` — `bash utilities/bashTestSuite/main.sh utilities/essentials/bashVersion/bashVersion_TEST.sh`.
