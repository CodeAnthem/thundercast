#!/usr/bin/env bash
# ==================================================================================================
# NDS - Test action
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-28 | Modified: 2026-09-26
# Description:   Read-only selftest action, hidden unless NDS_TEST is set
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

action_groups() {
    :
}

action_preview() {
    ui_h "NDS self-tests"
    ui_b "Runs the read-only test suite. No disk changes."
}
