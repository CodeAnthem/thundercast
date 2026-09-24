# Essentials

[![essentials selftest](https://github.com/CodeAnthem/thundercast/actions/workflows/essentials-selftest.yml/badge.svg)](https://github.com/CodeAnthem/thundercast/actions/workflows/essentials-selftest.yml)
[![essentials shellcheck](https://github.com/CodeAnthem/thundercast/actions/workflows/essentials-shellcheck.yml/badge.svg)](https://github.com/CodeAnthem/thundercast/actions/workflows/essentials-shellcheck.yml)

Shared runtime for a Bash program: events, logging, script identity, and a terminal UI.

## Overview

- **Event system** ([eventBus](eventBus/README.md), [trapBridge](trapBridge/README.md)) — named events with priority hooks. Signal and exit traps are events on the same bus.
- **Script information** ([scriptInfo](scriptInfo/README.md)) — directory, name, and version of the running script.
- **Logger** ([logger](logger/README.md)) — leveled console output, one log file per scope, and a compose file that merges scopes.
- **Importer** ([importer](importer/README.md)) — source `*.sh` files from a directory into the current shell.
- **UI format utilities** ([ui](ui/README.md)) — headings, indented text, key/value rows, numbered choices, banners, and sections.
- **Chrome** ([chrome](chrome/README.md)) — a TUI frame with a pinned header, a pinned footer, and a scrollable body.
- **Prompts** ([prompt](prompt/README.md)) — text, multiline, select, multi-select, confirm, a single key, or a pause.
- **Progress** ([progress](progress/README.md)) — a progress bar, as a string or as a live line.
- **Task line** ([task](task/README.md)) — one in-progress line, with a spinner and an OK or FAIL result.
- **TTY** ([ttyHandler](ttyHandler/README.md)) — keyboard modes for the session: a normal line, a hidden line, a single key, or discarded input.
- **Session directory** ([sessionDir](sessionDir/README.md)) — a scratch directory for this run, with named subdirectories.
- **Bash version** ([bashVersion](bashVersion/README.md)) — a minimum Bash major and minor for this runtime.
- **Root re-exec** ([rootReexec](rootReexec/README.md)) — an optional restart of the process as root.

Calls, flags, and defaults are in the linked README.

## Implement

Declare `essentials_config` in the same scope that loads essentials. Features read it through a nameref. `SCRIPTINFO_DIR`, `SCRIPTINFO_NAME`, and `SCRIPTINFO_VERSION` are required. Other keys are optional; each feature README lists its own.

```bash
declare -A essentials_config=(
    [SCRIPTINFO_DIR]="${script_dir}"
    [SCRIPTINFO_NAME]="Example"
    [SCRIPTINFO_VERSION]="0.1.0"
)

source /path/to/essentials.sh
essentials_init
```

Feature init shares `__ESSENTIALS_INIT`. A feature starts with `_essentials_init_isDone <name> && return 0` and calls `_essentials_init_mark <name>` after init succeeds. `rootReexec` marks before its early returns, so a second source does not walk the sudo path again. `bashVersion_check` stays callable after its init is marked.

| Keys | Owner |
|------|-------|
| `BASHVERSION_MAJOR` `BASHVERSION_MINOR` | [bashVersion](bashVersion/README.md) |
| `SCRIPTINFO_DIR` `SCRIPTINFO_NAME` `SCRIPTINFO_VERSION` | [scriptInfo](scriptInfo/README.md) |
| `LOG_*` | [logger](logger/README.md) |
| `TTY_EXIT_PRIORITY` | [ttyHandler](ttyHandler/README.md) |
| `RUNTIME_*` | [sessionDir](sessionDir/README.md) |
| `UI_MODE` `UI_NO_CLEAR` `UI_BANNER_MIN` `UI_LABEL_WIDTH` | [ui](ui/README.md) |
| `PROGRESS_WIDTH` `PROGRESS_FILL` `PROGRESS_EMPTY` | [progress](progress/README.md) |
| `CHROME_EXIT_PRIORITY` `CHROME_HEADER_*` `CHROME_FOOTER_*` `CHROME_TEMP_ROWS` `CHROME_HIST_MAX` | [chrome](chrome/README.md) |
| `UI_NO_PAUSE` | [prompt](prompt/README.md) |
| `TRAP_PRESETS` | [trapBridge](trapBridge/README.md) |
| `ROOTREEXEC_*` | [rootReexec](rootReexec/README.md) |
| `IMPORTER_INCLUDE_TESTS` | [importer](importer/README.md) |

`eventBus` and `task` do not read the map.

## Tests

Feature tests are [bashTestSuite](../bashTestSuite/README.md) suites. They load a dummy `essentials_config` from `testEnvironment/testEnvironment.sh`.

```bash
bash utilities/essentials/dev/selftest.sh
bash utilities/essentials/dev/shellcheck.sh
```
