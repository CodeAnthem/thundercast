# UI

Format toolkit: indent, color, rows, banner/section. Owns the screen events. Does not prompt or animate.

[![uses eventBus](https://img.shields.io/badge/uses-eventBus-2ea44f?style=flat-square)](../eventBus/README.md)
[![uses scriptInfo](https://img.shields.io/badge/uses-scriptInfo-2ea44f?style=flat-square)](../scriptInfo/README.md)
![subshells no](https://img.shields.io/badge/subshells-no-2ea44f?style=flat-square)

## Use

Call after essentials has loaded. Bootstrap lives in the [parent README](../README.md).

Printers write stderr. Before a block that needs the current line, fire `ui.line.take`. `ui_section` fires `ui.section.begin` before it clears. Step hooks those; other features may too.

### Config

Keys this feature reads from `essentials_config` (defaults from source). Map is filled in the [parent README](../README.md).

| Key | Default | Meaning |
|-----|---------|---------|
| `UI_MODE` | `auto` | `auto` `plain` `color` `unicode` (`unicode` → color on a TTY) |
| `UI_NO_CLEAR` | `false` | `true` skips the screen clear in `ui_section` |
| `UI_BANNER_MIN` | `56` | Minimum inner width of the banner box |
| `UI_LABEL_WIDTH` | `38` | Default width for `ui_kv` labels |

`NO_COLOR` forces plain. Color is detected once at init (`tput colors`).

### API

| Call | Arguments | Effect |
|------|-----------|--------|
| `ui_h` `ui_b` `ui_i` | `[text]` | Heading / body / inner line on stderr |
| `ui_warn` | `[text]` | Body warning (orange when color is on) |
| `ui_indentPush` | `[extra]` | Widen indents (default two spaces) |
| `ui_indentPop` | — | Restore last push |
| `ui_formatBool` | `true`/`false` | Print `yes`/`no` (no newline) |
| `ui_kv` | `<label>` `<value>` `[width]` | `label: value` row |
| `ui_choiceRow` | `<n>` `<name>` `[detail]` `[width]` | Numbered menu row |
| `ui_printMenu` | `<array-name>` `[back]` | Numbered rows only. `true` adds `0) Back` |
| `ui_banner` | `[subtitle]` | Box from scriptInfo name/version |
| `ui_section` | `[subtitle]` | `ui.section.begin`, optional clear, banner |

| Event | When |
|-------|------|
| `ui.line.take` | A block is about to write; CR widgets must vacate |
| `ui.section.begin` | About to clear/redraw; open progress is a bug |

### Examples

```bash
ui_section "Disk"
ui_h "Layout"
ui_kv "Device" "/dev/sda"
eventRun ui.line.take
```

## Design

- Toolkit only. Input is [prompt](../prompt/README.md). Progress is [task](../task/README.md). TTY policy is [ttyHandler](../ttyHandler/README.md). Optional frame is [chrome](../chrome/README.md) — `ui_section` calls `chrome_clear` then the banner when `chrome_isOn`.
- Event names are screen-shaped, not task-shaped. Zero hooks is a no-op.

## Develop

Init in `ui.sh`: config globals → base (detect color, unset detect) → section → `eventCreate` the two screen events.

Files: `ui.sh` init + events; `ui_base.sh` indent/color/rows; `ui_section.sh` banner and `eventRun ui.section.begin`.

Globals that must stay: `__UI_MODE` / `__UI_COLOR` / `__UI_NO_CLEAR` / indent trio + `__UI_INDENT_STACK` / `__UI_BANNER_*` / `__UI_LABEL_WIDTH` / `__UI_WARN_CODE`. Step reads `__UI_COLOR` and `__UI_INDENT_B`.

No subshells: `tput colors` at init is captured with `${ …; }` (tput still execs).

Do not:

- Call `tput` outside init
- Teach this feature about spinners or keys
- `eventRun` from a hook of these events (bus forbids nest)

### Tests

`ui_TEST.sh` — `bash utilities/bashTestSuite/main.sh utilities/essentials/ui/ui_TEST.sh`. TTY walk: `bash utilities/essentials/ui/ui_DEMO.sh`.
