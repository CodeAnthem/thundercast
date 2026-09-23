#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Prompt - Select
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-21 | Modified: 2026-09-21
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_ui_promptSelect() {
    _ui_promptMenuRun
}
