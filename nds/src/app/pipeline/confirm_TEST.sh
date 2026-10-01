#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install confirm
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
logger_setMinLevel warn
# shellcheck source=../session/mode.sh
source "$(dirname "${BASH_SOURCE[0]}")/../session/mode.sh"
# shellcheck source=../session/skip.sh
source "$(dirname "${BASH_SOURCE[0]}")/../session/skip.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")/../../recipe" --depth 0
import_dir "$(dirname "${BASH_SOURCE[0]}")/../../recipe/schema" --depth 0
import_dir "$(dirname "${BASH_SOURCE[0]}")/../../cook" --depth 0
# shellcheck source=confirm.sh
source "$(dirname "${BASH_SOURCE[0]}")/confirm.sh"

suite_confirm() {
    local _file _called
    nds_test_session
    export NDS_MODE=interactive
    nds_mode_resolve
    unset NDS_YES NDS_SKIP NDS_SKIP_INSTALL_CONFIRM
    _file="${ nds_session_dir recipe; }/sealed.recipe"
    printf '%s\n' 'INSTALL_MODE="local"' 'DISK_STRATEGY="flake"' 'COOK_PHASES="disk install_classic"' > "$_file"
    prompt() { UI_PROMPT_RESULT=n; }
    if nds_confirm "$_file" 2>/dev/null; then
        bts_fail "decline returned success"
    else
        bts_pass "decline returns 1"
    fi
    _called=0
    nds_confirm() { _called=1; }
    export NDS_SKIP_INSTALL_CONFIRM=true
    if ! nds_skip install.confirm; then
        nds_confirm "$_file"
    fi
    if [[ "$_called" -eq 0 ]]; then
        bts_pass "confirm is not called when install.confirm is skipped"
    else
        bts_fail "confirm ran while skipped"
    fi
}
