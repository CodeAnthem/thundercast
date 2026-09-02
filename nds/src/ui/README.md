# UI
Shared terminal UI: terminal, input (TTY guard), logger, section, prompts, stepAnimation.

When no prompt is active, NDS sets the TTY to discard keystrokes (no echo) and
keeps ISIG so **Ctrl+C** still aborts. Prompts call `nds_ui_tty_read` / enter+leave
to restore the TTY, drain typeahead, then re-block.
