# Progress

Progress bar. `progress_render` builds the string (chrome rows use it); `progress_begin` / `progress_set` / `progress_end` draw one CR line on stderr like task does. Does not prompt.

[![uses eventBus](https://img.shields.io/badge/uses-eventBus-2ea44f?style=flat-square)](../eventBus/README.md)
[![uses logger](https://img.shields.io/badge/uses-logger-2ea44f?style=flat-square)](../logger/README.md)
![subshells no](https://img.shields.io/badge/subshells-no-2ea44f?style=flat-square)

## Use

Call after essentials has loaded (after ui). Bootstrap lives in the [parent README](../README.md). Close every `progress_begin` with `progress_end` or `progress_cancel` before `ui_section`. Do not run a task line and a progress line at the same time — both own the CR line.

Works the same inside a [chrome](../chrome/README.md) body or on a plain console. For a bar pinned in a chrome bar use `chrome_setFooter <i> -t progress`.

### Config

| Key | Default | Meaning |
|-----|---------|---------|
| `PROGRESS_WIDTH` | `50` | Inline bar width in characters (≥ 10, includes label and counter) |
| `PROGRESS_FILL` `PROGRESS_EMPTY` | `#` / `-` | One character each |

### API

| Call | Arguments | Effect |
|------|-----------|--------|
| `progress_render` | `[-c] <cur> <max> <width> [label]` | Print `label [####----]  45%` exactly `width` wide. `-c` adds `cur/max`. Clamps cur to 0..max; max 0 is 0 % |
| `progress_begin` | `<max> [label]` | Open the inline bar at 0. Replaces an open one |
| `progress_set` | `<cur> [label]` | Move the bar; redraws only when the line changes |
| `progress_end` | `[label]` | Finish at 100 %, newline. Non-TTY prints the final line once |
| `progress_cancel` | — | Drop the line, no final line |
| `progress_isOpen` | — | True between begin and end/cancel |
| `progress_yield` | — | `ui.line.take` hook: vacate the line; the next `progress_set` redraws |

### Examples

```bash
progress_begin "${#files[@]}" "Copy"
for f in "${files[@]}"; do
    cp -- "$f" "$dest/"
    progress_set $((++n)) "Copy ${f##*/}"
done
progress_end "Copy"
```

## Design

- `progress_render` is pure: no tty, no globals except fill/empty characters. Width is exact — padded or clipped — so a chrome row can drop it in.
- Inline drawing is `\r\033[K` + indent + line, like task. The last rendered line is cached so a tight loop does not repaint identical frames.
- Hooks `ui.line.take` → `progress_yield` so a prompt can print under an open bar.

## Develop

Init in `progress.sh`: config → state → `eventRegister ui.line.take progress_yield`.

Globals that must stay: `__PROGRESS_OPEN` `__PROGRESS_CUR` `__PROGRESS_MAX` `__PROGRESS_LABEL` `__PROGRESS_LAST` `__PROGRESS_WIDTH` `__PROGRESS_FILL` `__PROGRESS_EMPTY` `__PROGRESS_INITIALIZED`. Reads `__UI_INDENT_B`.

Do not:

- Print from `progress_render`'s callers to stdout — stderr only, like the rest of the UI
- Call `ui_section` while a bar is open
- Add a spinner here (task owns it)

### Tests

`progress_TEST.sh` — `bash utilities/bashTestSuite/main.sh utilities/essentials/progress/progress_TEST.sh`. TTY walk: the "Inline progress" section of `bash utilities/essentials/chrome/chrome_DEMO.sh`.
