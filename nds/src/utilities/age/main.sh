#!/usr/bin/env bash
# ==================================================================================================
# age utility - age-keygen via pkg
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# ==================================================================================================

age_keygen() {
    if ! declare -f pkg_run &>/dev/null; then
        if declare -f nds_requireUtility &>/dev/null; then
            nds_requireUtility pkg || return 1
        else
            return 1
        fi
    fi
    pkg_run age-keygen age "$@"
}

age_onLoad() { return 0; }
age_onExit() { return 0; }
