#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - TTY - Presets
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-18 | Modified: 2026-09-24
# Description:   Named keyboard policies and character allowlists.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

# Apply a named TTY policy. Does not read input.
# Stty: idle | cooked | hidden | cbreak
# Charset (no getopts): digits | decimal | hex | alpha | lower | upper | alnum
tty_setPreset() {
    local name="${1:-}"
    case "${name,,}" in
        idle)
            _tty_setPolicy idle
            ;;
        cooked)
            _tty_setPolicy cooked
            ;;
        hidden)
            _tty_setPolicy hidden
            ;;
        cbreak)
            _tty_setPolicy cbreak
            ;;
        digits|decimal|hex|alpha|lower|upper|alnum)
            _tty_allowAppendPreset "${name,,}" || return 1
            _tty_allowActivate "${__TTY_ALLOW_BODY}" ''
            ;;
        "")
            error "Tty: tty_setPreset requires a name"
            return 1
            ;;
        *)
            error "Tty: unknown preset ${name}"
            return 1
            ;;
    esac
}
