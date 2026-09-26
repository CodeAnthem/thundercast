#!/usr/bin/env bash
# ==================================================================================================
# NDS - Finish screens
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../setup_TEST.sh"
logger_setMinLevel warn
# shellcheck source=session/mode.sh
source "$(dirname "${BASH_SOURCE[0]}")/session/mode.sh"
# shellcheck source=session/skip.sh
source "$(dirname "${BASH_SOURCE[0]}")/session/skip.sh"
# shellcheck source=finish.sh
source "$(dirname "${BASH_SOURCE[0]}")/finish.sh"

_rebooted=0
reboot() { _rebooted=1; }

suite_finish() {
    unset NDS_REBOOT NDS_YES NDS_SKIP
    export NDS_MODE=interactive
    nds_mode_resolve
    export NDS_SKIP_FINISH_BACKUP=true
    export NDS_SKIP_FINISH_REBOOT=true
    _rebooted=0
    nds_finish /no/such/sealed.recipe /tmp/nds_bundle.zip 2>/dev/null || { bts_fail "finish failed"; return; }
    if [[ "$_rebooted" -eq 0 ]]; then
        bts_pass "reboot is not called without NDS_REBOOT when finish.reboot is skipped"
    else
        bts_fail "reboot ran"
    fi
}
