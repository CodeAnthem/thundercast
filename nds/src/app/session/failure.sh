#!/usr/bin/env bash
# ==================================================================================================
# NDS - Failed-run log tails
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-09-27
# Description:   After chrome leaves the alternate screen, print the logger tail on the real terminal.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

# Chrome paints an alternate screen. exit restores the previous one, so anything drawn in the
# frame is gone. Write the tail to /dev/tty, which is that restored console.
_nds_session_print_scope() {
    local title="$1" scope="$2" lines="$3" path
    path=$(logger_scopeGetPath "$scope")
    {
        printf '\n%s\n' "$title"
        printf '%s\n\n' "Last ${lines} lines of ${path}:"
        if [[ "$scope" == internal_compose ]]; then
            logger_composeRead "-${lines}" || true
        else
            logger_scopeRead "$scope" "-${lines}" || true
        fi
    } >/dev/tty 2>/dev/tty || {
        printf '\n%s\n' "$title" >&2
        if [[ "$scope" == internal_compose ]]; then
            logger_composeRead "-${lines}" >&2 || true
        else
            logger_scopeRead "$scope" "-${lines}" >&2 || true
        fi
    }
}

nds_session_showFailure() {
    _nds_session_print_scope "NDS failed (exit ${1:-?})." internal_compose 40
}
