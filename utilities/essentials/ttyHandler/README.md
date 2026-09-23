# TTY

Session TTY policy: what the keyboard can do, and restore it on EXIT. Does not prompt.

[![uses eventBus](https://img.shields.io/badge/uses-eventBus-2ea44f?style=flat-square)](../eventBus/README.md)
[![uses logger](https://img.shields.io/badge/uses-logger-2ea44f?style=flat-square)](../logger/README.md)
![subshells no](https://img.shields.io/badge/subshells-no-2ea44f?style=flat-square)

## Use

Call after essentials has loaded (after eventBus and logger). Bootstrap lives in the [parent README](../README.md). Guard is **off** until `tty_guardEnable`. UI/`prompt` choose *when* to change policy; this feature only applies it.

One current **policy**:

| Policy | Keyboard |
|--------|----------|
| `idle` | Keys discarded (Ctrl+C still works) |
| `cooked` | Normal line (echo, Enter ends the line) |
| `hidden` | Line, no echo |
| `cbreak` | One key, no echo |
| `allow` | One key; only the set (plus Enter / backspace) |

`tty_guardEnable` once at app start (snapshot + idle). Around each prompt: `tty_begin` → preset or `tty_allow` → `tty_read` / `tty_getc` → `tty_end`. First begin (guard on) drains mash and leaves idle (cooked). EXIT already calls `tty_restore` (`TRAP_PRESETS=true`; NDS already). Do not capture `tty_read` / `tty_getc`.

### Config

Keys this feature reads from `essentials_config` (defaults from source). Map is filled in the [parent README](../README.md).

| Key | Default | Meaning |
|-----|---------|---------|
| `TTY_EXIT_PRIORITY` | `10` | `eventRegister exit tty_restore` priority (lower runs first) |

### API

| Call | Arguments | Effect |
|------|-----------|--------|
| `tty_ok` | — | True if this process can open the controlling TTY |
| `tty_guardEnable` | — | Snapshot `stty`; start idle discard. No-op if already on or no TTY |
| `tty_restore` | — | Original `stty`. Clears guard. EXIT hook; idempotent |
| `tty_pending` | — | True if bytes are waiting (does not consume) |
| `tty_drain` | — | Throw away typeahead |
| `tty_begin` / `tty_end` | — | First begin (guard on): drain, cooked. Last end: idle again |
| `tty_setPreset` | `<name>` | Stty or charset shortcut (no `getopts`) |
| `tty_allow` | `[-p name]… [-a chars] [-x chars] [chars]` | Union, then subtract. Literal keys |
| `tty_read` | `read` args | `read "$@" </dev/tty`. With `__TTY_READ_TICK` set (chrome on) the wait is sliced and `__TTY_TICK_HOOK` runs between slices; no `-p` then |
| `tty_getc` | `<var> [raw]` | One key into `var`. Idle or EOF → 1. `raw` skips allow (CSI tail) |

| Name | Meaning |
|------|---------|
| `idle` `cooked` `hidden` `cbreak` | Stty. `tty_setPreset` only, not `-p` |
| `digits` | `0-9` |
| `decimal` | `0-9.` |
| `hex` | `0-9A-Fa-f` |
| `alpha` | `A-Za-z` |
| `lower` `upper` | one case |
| `alnum` | `A-Za-z0-9` |

`-a` / `-x` / leftover args are the bytes the shell already parsed. No backslash decode, no trim. `-a abc` is a, b, c. Empty set after `-x` is an error.

```bash
tty_allow -p alpha -a '123[]'
tty_allow -p alpha -x t
tty_allow -x " "          # space
tty_allow -x '"'          # double-quote
tty_allow -x "'"          # single-quote
```

Quote `[` `]` `*` so the caller’s glob does not eat them. A leftover that starts with `-` needs `--` or `-a '...'`.

### Examples

```bash
tty_guardEnable
tty_begin
tty_setPreset cooked
tty_read -r -p "Name: " name
tty_end

tty_begin
tty_setPreset digits
# print "Port: " then loop tty_getc until Enter
tty_allow -p alpha -a '[]' -x t
tty_end
```

## Design

- Prompt text, paste, and validation stay in [prompt](../prompt/README.md).
- Charset names are keystrokes, not valid ports or IPs.
- Register `exit`, not `exitClean`. Drain: never `while read -t 0`.
- Sliced reads exist because bash defers traps while a builtin `read` blocks and has one read timer: a trap that needs to paint (chrome WINCH) sets a flag while `__TTY_READING` is 1 and the hook paints between slices. Without a tick the read is byte-identical to before.

## Develop

Init in `ttyHandler.sh`: config → controller → presets → `eventRegister exit tty_restore`. After logger, before sessionDir. Skip `eventRegister` only if the bus is missing. `error` for caller mistakes. Restore must not `error`/`fatal`. Non-numeric `TTY_EXIT_PRIORITY` fails init. Snapshot with `${ { stty -g; } 2>/dev/null </dev/tty; }` (current shell; `stty` still execs).

Files: `ttyHandler.sh` init; `tty_controller.sh` stty/drain/read/getc/`tty_allow`; `tty_presets.sh` `tty_setPreset`.

Globals: `__TTY_GUARD` `__TTY_STTY` `__TTY_DEPTH` `__TTY_POLICY` `__TTY_ALLOW_SET` `__TTY_ALLOW_BODY` `__TTY_READ_TICK` `__TTY_TICK_HOOK` `__TTY_READING` `__TTY_EXIT_PRIORITY`. Map keys are byte codes (`printf %d "'$ch"`) because `unset` of a raw `"` key is a no-op. `_tty_allowAppendPreset` writes `__TTY_ALLOW_BODY`. `decimal` / `hex` / `alpha` / `alnum` are composed from `digits` / `upper` / `lower`. `tty_getc` locals are `_tty_*` so `printf -v` cannot hit them when the dest is `ch` or `dest`.

Do not:

- Parse `read` flags in `tty_read`
- Glob-wrap allow sets
- Assign `__TTY_ALLOW_SET` before the new set is known non-empty
- `trapRegister INT`; auto `tty_guardEnable`; fail the EXIT hook
- Duplicate charset tables in UI

### Tests

`ttyHandler_TEST.sh` — `bash utilities/bashTestSuite/main.sh utilities/essentials/ttyHandler/ttyHandler_TEST.sh`.
