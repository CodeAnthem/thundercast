#!/usr/bin/env bash
# ==================================================================================================
# Git utility - interactive flag
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-29 | Modified: 2026-08-30
# Description:   GIT_INTERACTIVE=1 force on, =0 force off; unset follows tty
# ==================================================================================================

# Description: True when prompts are allowed.
# Returns:
# - <Bool> 0 when interactive
git_helper_interactive_isEnabled() {
    case "${GIT_INTERACTIVE:-}" in
        1) return 0 ;;
        0) return 1 ;;
    esac
    [[ -t 0 && -t 1 ]]
}
