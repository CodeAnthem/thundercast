#!/usr/bin/env bash
# ==================================================================================================
# NDS - CLI flags
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-10-01 | Modified: 2026-10-01
# Description:   --import and --restore stay interactive and name a file
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
logger_setMinLevel warn
# shellcheck source=cli.sh
source "$(dirname "${BASH_SOURCE[0]}")/cli.sh"
# shellcheck source=../actionSelect/action.sh
source "$(dirname "${BASH_SOURCE[0]}")/../actionSelect/action.sh"

_cli_clear() {
    unset NDS_MODE NDS_IMPORT NDS_RESTORE_FILE NDS_RECIPE_FILE NDS_ACTION NDS_YES
}

suite_cli() {
    local rc file
    _cli_clear
    file=$(mktemp)
    printf '%s\n' 'INSTALL_ACTION="classicInstall"' > "$file"

    rc=0
    nds_cli_parse --import "$file" || rc=$?
    if [[ "$rc" -eq 0 && ${NDS_IMPORT:-} == 1 && ${NDS_RECIPE_FILE:-} == "$file" && -z ${NDS_MODE:-} ]]; then
        bts_pass "--import keeps the run interactive and points at the recipe"
    else
        bts_fail "--import rc=${rc} mode='${NDS_MODE:-}' file='${NDS_RECIPE_FILE:-}'"
    fi

    _cli_clear
    export NDS_IMPORT=1
    rc=0
    _nds_action_preview_skipped || rc=$?
    if [[ "$rc" -eq 1 ]]; then
        bts_pass "--import does not skip the preview"
    else
        bts_fail "preview skip rc was ${rc}"
    fi

    _cli_clear
    rc=0
    nds_cli_parse --unattended --import "$file" 2>/dev/null || rc=$?
    if [[ "$rc" -eq 1 ]]; then
        bts_pass "--import refuses unattended"
    else
        bts_fail "--import unattended rc was ${rc}"
    fi

    _cli_clear
    rc=0
    nds_cli_parse --import "$file" --restore "$file" 2>/dev/null || rc=$?
    if [[ "$rc" -eq 1 ]]; then
        bts_pass "--import and --restore together are refused"
    else
        bts_fail "together rc was ${rc}"
    fi

    _cli_clear
    rc=0
    nds_cli_parse apply "$file" 2>/dev/null || rc=$?
    if [[ "$rc" -eq 1 ]]; then
        bts_pass "apply is not a command"
    else
        bts_fail "apply rc was ${rc}"
    fi

    rm -f "$file"
    _cli_clear
}
