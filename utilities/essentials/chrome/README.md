# Chrome

Optional frame: pinned header rows, pinned footer rows, body in the middle that looks like a normal console. Off until `chrome_begin`.

[![uses eventBus](https://img.shields.io/badge/uses-eventBus-2ea44f?style=flat-square)](../eventBus/README.md)
[![uses logger](https://img.shields.io/badge/uses-logger-2ea44f?style=flat-square)](../logger/README.md)
[![uses progress](https://img.shields.io/badge/uses-progress-2ea44f?style=flat-square)](../progress/README.md)
[![uses scriptInfo](https://img.shields.io/badge/uses-scriptInfo-2ea44f?style=flat-square)](../scriptInfo/README.md)
[![uses sessionDir](https://img.shields.io/badge/uses-sessionDir-2ea44f?style=flat-square)](../sessionDir/README.md)
[![uses trapBridge](https://img.shields.io/badge/uses-trapBridge-2ea44f?style=flat-square)](../trapBridge/README.md)
[![uses ttyHandler](https://img.shields.io/badge/uses-ttyHandler-2ea44f?style=flat-square)](../ttyHandler/README.md)
![subshells yes](https://img.shields.io/badge/subshells-yes-d73a49?style=flat-square)

## Use

Call after essentials has loaded (after ui, progress and tty). Bootstrap lives in the [parent README](../README.md). Do not call `chrome_begin` unless you want the frame. No TTY → begin is a no-op and chrome stays off.

While on: alt screen (`1049`) + DECSTBM keep the header and footer rows still. Logger, `ui_*`, task, progress and prompt keep writing stderr; chrome tees fd 2 (and fd 1 when it is the terminal) to the tty and into a body history. Wheel / PageUp / PageDown / Home / End at a prompt scroll that history in the body only (the terminal's own scrollbar does nothing on the alt screen); the title row shows `[history -n]` while scrolled and the view snaps back to live when the prompt ends. `ui_section` wipes the body and prints `ui_banner` at the body top; earlier sections stay reachable by scrolling up. A resize is a full redraw from history, prompt line included. Pair `chrome_end` with `tty_restore`.

### Rows

Header and footer are lists of rows (`CHROME_HEADER_ROWS` / `CHROME_FOOTER_ROWS`, changeable at runtime). Each row has a type:

| Type | Draws | Props |
|------|-------|-------|
| `title` | script name + version, `[history -n]` on the right while scrolled | `-a` `-r` |
| `text` | free text (default) | `-a left\|center\|right` `-r <right slot>` |
| `sep` | one character repeated across the width | `-c <char>` |
| `spacer` | blank bar | — |
| `progress` | `progress_render -c` over the full width | `-v <value>` `-m <max>`, text = label |
| `hint` | items spread evenly (`Enter:ok … Esc:cancel`) | one item per argument |

Every row takes `-f <fg>` `-b <bg>` (`black`…`white`, `0-255`, or `reverse`); unset rows use the bar's `CHROME_*_FG/BG`. Options may come before or after the text. The body keeps at least 3 rows on a small terminal: footer rows give way first, then header rows; they come back when the window grows.

### Config

Keys this feature reads from `essentials_config` (defaults from source). Map is filled in the [parent README](../README.md).

| Key | Default | Meaning |
|-----|---------|---------|
| `CHROME_EXIT_PRIORITY` | `5` | `eventRegister exit chrome_end` (runs before tty restore) |
| `CHROME_HEADER_ROWS` `CHROME_FOOTER_ROWS` | `2` / `1` | Initial row counts (0–20). Header row 0 is `title`, row 1 the subtitle |
| `CHROME_HEADER_BG` `CHROME_HEADER_FG` | `reverse` / empty | Default bar colours: `reverse`, `black`…`white`, or `0-255` |
| `CHROME_FOOTER_BG` `CHROME_FOOTER_FG` | `reverse` / empty | Same for the footer |
| `CHROME_TEMP_ROWS` | `12` | Unused by prompt (temp API only) |
| `CHROME_HIST_MAX` | `1000` | Body history cap (lines) |

### API

| Call | Arguments | Effect |
|------|-----------|--------|
| `chrome_isOn` | — | True after a successful `chrome_begin` (false while suspended) |
| `chrome_begin` | `[subtitle]` | Alt screen, bars, DECSTBM, hist tee, SGR mouse. No-op if on or no TTY. rc 1 only if the tee cannot start |
| `chrome_end` | — | Flush the tee, restore fds, mouse off, reset region, leave alt screen. Idempotent. EXIT hook |
| `chrome_setHeader` / `chrome_setFooter` | `<i> [opts] [text…]` | Set row i (see Rows); repaint that row only while on. Bad index/type/colour → `error`, rc 1 |
| `chrome_setHeaderRows` / `chrome_setFooterRows` | `<n>` | Change the row count (0–20); full redraw while on. Row content is kept |
| `chrome_getHeaderRows` / `chrome_getFooterRows` | — | Configured counts |
| `chrome_setSubtitle` | `[text]` | Header row 1 text (short for `chrome_setHeader 1 -- text`) |
| `chrome_getCols` / `chrome_getBodyRows` | — | Current width / body height (measures when off) |
| `chrome_repin` | — | Size + DECSTBM + bars; body cursor stays. Prompt calls it after `stty` |
| `chrome_redraw` | — | Full repaint: bars + body from history + pending prompt line. Use after something else drew on the screen |
| `chrome_suspend` / `chrome_resume` | — | Leave the frame (history kept, `chrome_isOn` false) / come back with a full redraw |
| `chrome_run` | `<cmd…>` | `suspend`, run the command on the normal screen, `resume`. Returns its rc. Off → just runs it |
| `chrome_isSuspended` | — | True between suspend and resume |
| `chrome_setMouse` | `on\|off` | SGR mouse reporting. Prompt turns it off for cooked sessions |
| `chrome_clear` | — | Wipe the body, cursor at the body top. History keeps the old lines; the live view starts here |
| `chrome_home` | — | Cursor at the body top. No erase |
| `chrome_clearLine` | — | Wipe the current body row |
| `chrome_clearLines` | `<n>` | Wipe the last n body rows (inclusive). Cursor at the first wiped row. Bad n → no-op |
| `chrome_clearToEnd` | — | Wipe from the current row through the body bottom |
| `chrome_scrollUp` / `chrome_scrollDown` | `[n]` | Body history (default one page; wheel uses 3) |
| `chrome_follow` | — | Back to the live tail. No-op unless scrolled |
| `chrome_tempBegin` / `chrome_tempEnd` / `chrome_isTemp` | — | Mark the current body row / erase from the mark to the body bottom |

### Examples

```bash
tty_guardEnable
chrome_begin "Disk"
chrome_setFooterRows 4
chrome_setFooter 0 -t sep -c "─"
chrome_setFooter 1 "Current file:" -r "0/12"
chrome_setFooter 2 -t progress -m 12 "Copy"
chrome_setFooter 3 -t hint "Enter: ok" "PgUp/PgDn: history" "Esc: cancel"
ui_section "Copy"
for ((i = 1; i <= 12; i++)); do
    chrome_setFooter 1 "Current file: part-${i}" -r "${i}/12"
    chrome_setFooter 2 -v "$i"
    ui_i "copied part-${i}"
done
chrome_setFooterRows 1
chrome_setFooter 0 -t hint "Enter: continue"
prompt --type confirm "Continue?"      # PageUp here scrolls the body, not cancel
chrome_run vim /etc/hosts               # frame gone while vim runs, back after
chrome_end
tty_restore
```

## Design

- Off is the compatibility contract. Other features only branch on `chrome_isOn` (`ui_section`, prompt session begin/end + scroll keys). Logger, task and progress are untouched.
- Bars are rows, not `ui_banner`. Row state lives in `__CHROME_HEADER` / `__CHROME_FOOTER` (`"<i>.<prop>"` keys) so a row set while off is painted at begin. `ui_section` never changes header rows.
- Alt screen + DECSTBM. Main screen would let the terminal scrollbar drag the title away; the alt screen has no scrollback, so chrome owns history.
- fd 2 → tee (process substitution) → tty + history file. fd 1 joins when it is the terminal (`echo` keeps its order and lands in history); a piped stdout stays a pipe. The tee forwards **bytes** as they arrive (one blocking byte, then the rest of the line with a 20 ms timeout), so prompts and `\r` spinner frames show immediately; complete lines are recorded, the pending partial line is mirrored to `<hist>.partial` so a redraw can re-emit it.
- Chrome paints go to a tty fd saved at begin, never through the tee. Before every paint chrome writes a `\001chrome:sync\001` line to fd 2 and waits for the tee's ack on a FIFO — that orders a body wipe or bar repaint after everything the app already wrote. `chrome_clear` sends `\001chrome:clear\001` instead, which the tee also stores as the section boundary.
- History lines are what a scrolled view should show: a leading `ESC[nA` (menu redraw) drops the previous n lines, other CSI except SGR are removed, `\r` keeps the tail, `\b` rubs out.
- View model: the body is `height-1` history rows plus the cursor row, like a console whose last `\n` left the cursor on a free line. Live start is `max(section boundary, lines - view)`. Scrolling back past the boundary shows earlier sections. After a render the cursor is on the row after the last shown line, so a prompt reprint (`\r` + label, or the menu's cursor-up redraw) replaces its own frame.
- Redraw (`chrome_redraw`, WINCH, resume, row-count change) is the only `2J` while on: a resize can smear bar colours into the body, so wipe, bars, region, body from history, partial line.
- WINCH while a `tty_read` is in flight only sets a flag; `tty_read` slices its wait (`__TTY_READ_TICK`) and runs `_chrome_tick` between slices. bash has one read timer, so a redraw (its `read -t` on the ack FIFO) inside the trap would leave the prompt's read waiting forever.
- Suspend keeps the history file and closes the tee; resume reopens the tee on that file (the tee preloads it) and redraws. Output while suspended goes to the normal screen, not into history.
- DECSTBM homes the cursor: always DECSC/DECRC around `ESC[…r`. `ESC[r` only when leaving.
- Mouse is SGR (`1000`/`1006`). Wheel 64/65 become `wheelup`/`wheeldn` tokens in prompt. Never `1007` (would drive select menus). Off during cooked/hidden prompt sessions so reports cannot land in typed text.
- CPR (`ESC[6n`) is read with the tty temporarily raw; a cooked tty would hold the reply for the next prompt.
- `chrome_tempBegin` / `chrome_tempEnd` stay available. Prompt does not call them.

## Develop

Init in `chrome.sh`: config → layout → bars → hist → `eventRegister exit chrome_end`. After ui, progress and tty, before task. `error` for a bad priority / row count / `CHROME_HIST_MAX` / `CHROME_TEMP_ROWS`. `chrome_end` must not `error`/`fatal`.

| File | Role |
|------|------|
| `chrome.sh` | Init, begin/end/suspend/resume/run, redraw, mouse, body erase, temp slot, WINCH + tick |
| `chrome_layout.sh` | Size, row counts → region, colours (`_chrome_sgr`), fit, DECSTBM save/restore, park, clear range, CPR, `_chrome_redraw` |
| `chrome_bars.sh` | Row model, row text per type, row/bar paint, `chrome_setHeader` / `chrome_setFooter` / `*Rows` |
| `chrome_hist.sh` | Tee (`_chrome_tee`, runs in the fd-2 process substitution), partial mirror, markers/ack, history load/render, scroll/follow |

Globals: `__CHROME_ON` `__CHROME_SUSPENDED` `__CHROME_TEMP*` `__CHROME_HEADER` `__CHROME_FOOTER` `__CHROME_*_ROWS` `__CHROME_*_SHOW` `__CHROME_*_BG/FG` `__CHROME_LINES` `__CHROME_COLS` `__CHROME_BODY_*` `__CHROME_LOG_ROW` `__CHROME_WINCH` `__CHROME_WINCH_PENDING` `__CHROME_MOUSE` `__CHROME_SCROLL` `__CHROME_TTY` `__CHROME_ERR` `__CHROME_OUT` `__CHROME_ACK` `__CHROME_HIST_PATH` `__CHROME_ACK_PATH` `__CHROME_VIEW` `__CHROME_VIEW_BASE` `__CHROME_FILTERED*` `__CHROME_MARK_*` `__CHROME_EXIT_PRIORITY` `__CHROME_INITIALIZED`. Tee-only: `__CHROME_TEE_*`. Sets tty's `__TTY_READ_TICK` / `__TTY_TICK_HOOK` while on.

Intentional subshells: `${ { stty size; } … </dev/tty; }`, `${ { stty -g; } … }`, the tee process substitution.

`[[ -t 1 ]]` / `[[ -t 2 ]]` are false while chrome is on. Anything that means "we have a console" must use `tty_ok` / `/dev/tty`.

Do not:

- Auto-`chrome_begin` on load
- Full-screen `\033[2J` outside `_chrome_redraw`
- Put this API on `ui_*`
- Redirect fd 1/2 except via `_chrome_histStart`
- Paint the tty without `_chrome_sync` first
- `read -t` inside `chrome_onWinch` (flag it, let `_chrome_tick` paint)
- Promise the terminal scrollbar (alt screen has none; use wheel/PageUp)
- Bring back `chrome_onSection` or add `chrome_log`

### Tests

`chrome_TEST.sh` — `bash utilities/bashTestSuite/main.sh utilities/essentials/chrome/chrome_TEST.sh`. TTY walk: `bash utilities/essentials/chrome/chrome_DEMO.sh` (outside tmux for a real wheel; resize the window during a prompt).
