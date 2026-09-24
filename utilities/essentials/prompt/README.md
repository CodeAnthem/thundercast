# Prompt

One `prompt` command. Interaction only: no regex, trim, or wizard steps. TTY policy is [ttyHandler](../ttyHandler/README.md).

[![uses eventBus](https://img.shields.io/badge/uses-eventBus-2ea44f?style=flat-square)](../eventBus/README.md)
[![uses trapBridge](https://img.shields.io/badge/uses-trapBridge-2ea44f?style=flat-square)](../trapBridge/README.md)
[![uses ttyHandler](https://img.shields.io/badge/uses-ttyHandler-2ea44f?style=flat-square)](../ttyHandler/README.md)
[![uses ui](https://img.shields.io/badge/uses-ui-2ea44f?style=flat-square)](../ui/README.md)
![subshells no](https://img.shields.io/badge/subshells-no-2ea44f?style=flat-square)

## Use

Call after essentials has loaded. Bootstrap lives in the [parent README](../README.md). Do not capture `prompt`. The caller validates and decides what Back means. Empty multi-select is success — the caller enforces “at least N”.

`prompt` fires `ui.line.take` first so a CR widget can vacate. It does not name task. When [chrome](../chrome/README.md) is on: `chrome_repin` runs after stty, mouse reporting is off for cooked/hidden sessions, and the session end jumps the body back to the live tail (`chrome_follow`).

### Config

Keys this feature reads from `essentials_config` (defaults from source). Map is filled in the [parent README](../README.md).

| Key | Default | Meaning |
|-----|---------|---------|
| `UI_NO_PAUSE` | `false` | `true` makes `--type pause` a no-op |

Color follows `__UI_COLOR` unless `--plain` / `--no-color` / `NO_COLOR`.

### API

Type defaults to `text` when a message is given. Remaining args are the message unless `--message` is set. Sets `UI_PROMPT_RESULT` and `UI_PROMPT_ACTION`.

| Flag | Meaning |
|------|---------|
| `--type` `-t` | `text` `multiline` `select` `multi-select` `confirm` `key` `pause` |
| `--message` | Question text |
| `--default` `-d` | Empty submit fallback. Confirm: `y`/`n`. Multiline: empty body closed by `--end`. Not valid with multi-select |
| `--allow-empty` `-a` | Allow empty submit (text / multiline only) |
| `--hide` `-H` `-s` | No echo (text / multiline) |
| `--mask CHAR` | Echo CHAR per key (text only; not with `--hide`) |
| `--end` `-e` | Multiline terminator line (required for multiline) |
| `--include-end` | Keep the terminator in the result |
| `--options` `-o` | Select / multi-select: array name. Entries `value` or `value\|label` or `value\|label\|description` |
| `--selected` | Multi-select: array name of initial values, labels, or 1-based indexes |
| `--bind ACTION=KEY` | Override a key. Actions: `submit` `back` `cancel` `help` `toggle` |
| `--back` `-b` | Bind Back to `b` (and `0` on select / multi-select) |
| `--description` `--placeholder` `--prefix` `--suffix` `--footer` | Presentation |
| `--help TEXT` | Help overlay (`?` by default) |
| `--plain` `--no-color` | No fancy select / no color |

| rc | `UI_PROMPT_ACTION` | Notes |
|----|--------------------|-------|
| 0 | `submit` | Includes confirm No (`n`) and allowed empty |
| 2 | `back` | Caller navigates |
| 3 | `cancel` | Esc by default |
| 1 | — | Bad flags, no TTY session, or an internal prompt error |
| 4 | — | Read failed (EOF). Prior multiline lines are discarded |
| 130 | — | Ctrl+C via `taskOnInt` / `trap.INT`, not returned by `prompt` |

Select: arrows or `1-9` move, Enter submits the cursor. Multi-select: Space/`1-9` toggle, Enter submits checked values as a newline-separated `UI_PROMPT_RESULT` (empty set is ok). Description lines print only when an option has one. `UI_MODE=plain` or `--plain` uses a numbered line; a select number plus Enter submits. One-key types reject paste.

### Examples

```bash
trapRegister INT taskOnInt
tty_guardEnable
prompt --type confirm -b "Proceed?"
prompt --type select --options envs -b "Environment"
prompt --type multi-select --options feats --selected pre -b "Features"
prompt --type text --default nixos "Hostname"
```

## Design

- Maps keys and draws the widget. `tty_*` owns stty. Confirm uses `tty_allow` (`y/n` plus binds). Select stays `cbreak` because arrows are ESC sequences and allow is per-byte. PageUp / PageDown / Home / End / wheel scroll chrome history when chrome is on; they are not Esc/cancel. After a scroll the widget reprints in place (`\r` for one-line widgets, cursor-up redraw for menus).
- `ui_printMenu` still draws a static list; select / multi-select draw from `--options` via `prompt_menu.sh`.
- Multiline INT/TERM uses `trapRegister` when present; raw `trap` only if not.

## Develop

Init in `prompt.sh`: `UI_NO_PAUSE` + result globals → input → types → menu → select → multi.

Files: `prompt.sh` parse/bind/dispatch; `prompt_input.sh` session/keys/line editor; `prompt_types.sh` confirm/text/multiline/key/pause; `prompt_menu.sh` list draw/loop; `prompt_select.sh` / `prompt_multi.sh` thin wrappers (`--selected` lives in multi).

Globals that must stay: `UI_PROMPT_RESULT`, `UI_PROMPT_ACTION`, `__UI_NO_PAUSE`, `__PROMPT` (session scalars; reset must set every key — `set -u` treats a missing key as unbound), `__UI_PROMPT_BIND`, `__UI_PROMPT_OPT_*` (including `OPT_ON` for checks), `__UI_BLOCK_*`. Do not add per-flag scalars.

No subshells: `trap -p` snapshots use `${ …; }`.

Do not:

- Capture `prompt` with `$(fn)` or `${ prompt; }`
- `local -n` a scalar result; use `UI_PROMPT_RESULT`
- Call `taskYield` / `taskResume` from here
- Re-implement idle/stty (`tty_*`)
- Raw-`trap` INT/TERM when `trapRegister` exists
- Add a third-party TUI

### Tests

`prompt_TEST.sh` — `bash utilities/bashTestSuite/main.sh utilities/essentials/prompt/prompt_TEST.sh`. TTY walk: `bash utilities/essentials/prompt/prompt_DEMO.sh`.
