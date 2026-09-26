#!/usr/bin/env bash
# ==================================================================================================
# age - keygen goes through pkg
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")" --depth 0

_age_log=()
pkg_run() { _age_log+=("$*"); return 0; }

suite_age() {
    age_keygen -o /tmp/key.txt
    if [[ "${_age_log[0]}" == 'age-keygen age -o /tmp/key.txt' ]]; then
        bts_pass "age_keygen runs age-keygen through pkg"
    else
        bts_fail "age_keygen called '${_age_log[0]-}'"
    fi
}
