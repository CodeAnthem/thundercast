#!/usr/bin/env bash
# ==================================================================================================
# NDS - Input validator tests (read-only)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-06-29
# ==================================================================================================

suite_inputs() {
    local test_root="${SCRIPT_DIR}/app/settingsManager/tests/specs"
    local test_file

    for test_file in "$test_root"/inputs/**/*.sh; do
        [[ -f "$test_file" ]] || continue
        # shellcheck disable=SC1090
        source "$test_file"
    done

    local test_func
    for test_func in $(declare -F | awk '{print $3}' | grep '^test_'); do
        console "  → $test_func"
        "$test_func"
    done
}
