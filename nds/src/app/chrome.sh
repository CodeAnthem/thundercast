#!/usr/bin/env bash
# ==================================================================================================
# NDS - Chrome colours
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-24 | Modified: 2026-09-24
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_nds_chrome_subtitleIdle() {
    chrome_setHeader 1 -b 238 -f 250
}

_nds_chrome_subtitleWait() {
    chrome_setHeader 1 -b 24 -f 255
}

chrome_setHeader 0 -b 236 -f 255
_nds_chrome_subtitleIdle
eventRegister prompt.pre _nds_chrome_subtitleWait
eventRegister prompt.post _nds_chrome_subtitleIdle
