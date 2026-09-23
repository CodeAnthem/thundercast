#!/usr/bin/env bash
# ==================================================================================================
# NDS - Menu skip + action select (sessionControl)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-09-02
# ==================================================================================================

suite_skip() {
    unset NDS_AUTO_CONFIRM NDS_INSTALL_CONFIRM_SKIP

    if nds_env_is_true true && nds_env_is_true 1; then
        bts_pass "ok"
        console "  ✓ nds_env_is_true: true and 1"
    else
        bts_fail "fail"
        console "  ✗ nds_env_is_true: true and 1"
    fi

    if ! nds_env_is_true false && ! nds_env_is_true ""; then
        bts_pass "ok"
        console "  ✓ nds_env_is_true: false and empty"
    else
        bts_fail "fail"
        console "  ✗ nds_env_is_true: false and empty"
    fi

    export NDS_INSTALL_CONFIRM_SKIP=true
    if nds_skip_menu NDS_INSTALL_CONFIRM_SKIP; then
        bts_pass "ok"
        console "  ✓ nds_skip_menu: specific flag"
    else
        bts_fail "fail"
        console "  ✗ nds_skip_menu: specific flag"
    fi
    unset NDS_INSTALL_CONFIRM_SKIP

    export NDS_CAST_WARN_SKIP=true
    if nds_skip_menu NDS_CAST_WARN_SKIP; then
        bts_pass "ok"
        console "  ✓ nds_skip_menu: NDS_CAST_WARN_SKIP"
    else
        bts_fail "fail"
        console "  ✗ nds_skip_menu: NDS_CAST_WARN_SKIP"
    fi
    unset NDS_CAST_WARN_SKIP

    if declare -f nds_skip_register &>/dev/null \
        && [[ " ${_NDS_SKIP_REGISTRY[*]} " == *" NDS_CAST_WARN_SKIP "* ]]; then
        bts_pass "ok"
        console "  ✓ skip_register: NDS_CAST_WARN_SKIP"
    else
        bts_fail "fail"
        console "  ✗ skip_register: NDS_CAST_WARN_SKIP missing"
    fi

    export NDS_AUTO_CONFIRM=true
    if nds_skip_menu NDS_INSTALL_CONFIRM_SKIP; then
        bts_pass "ok"
        console "  ✓ nds_skip_menu: NDS_AUTO_CONFIRM umbrella"
    else
        bts_fail "fail"
        console "  ✗ nds_skip_menu: NDS_AUTO_CONFIRM umbrella"
    fi
    unset NDS_AUTO_CONFIRM

    nds_skip_all
    if [[ "${NDS_GIT_AUTH_SKIP:-false}" != "true" ]]; then
        bts_pass "ok"
        console "  ✓ skip_all: does not set NDS_GIT_AUTH_SKIP"
    else
        bts_fail "fail"
        console "  ✗ skip_all: must not skip git auth wizard"
    fi
    local _skip_var
    for _skip_var in "${_NDS_SKIP_REGISTRY[@]}"; do
        unset "$_skip_var"
    done
    unset NDS_AUTO_CONFIRM

    nds_app_actionManager_logic_discover "${SCRIPT_DIR}/actions" || return 1
    export NDS_ACTION=installFlake
    NDS_CURRENT_ACTION=""
    if nds_app_actionManager_logic_selectFromEnv && [[ "$NDS_CURRENT_ACTION" == "installFlake" ]]; then
        bts_pass "ok"
        console "  ✓ selectFromEnv: installFlake"
    else
        bts_fail "fail"
        console "  ✗ selectFromEnv: installFlake"
    fi

    export NDS_ACTION=not_a_real_action
    NDS_CURRENT_ACTION=""
    if ! nds_app_actionManager_logic_selectFromEnv 2>/dev/null; then
        bts_pass "ok"
        console "  ✓ selectFromEnv: rejects invalid action"
    else
        bts_fail "fail"
        console "  ✗ selectFromEnv: rejects invalid action"
    fi
    unset NDS_ACTION NDS_CURRENT_ACTION

    local prepare_out=""
    if prepare_out=$(
        env SCRIPT_DIR="$SCRIPT_DIR" "$BASH" -euo pipefail -c '
            source "${SCRIPT_DIR}/app/main.sh"
            nds_app_bootstrap "$SCRIPT_DIR" || exit 1
            nds_app_prepareAction || exit 1
            declare -f nds_git_owner_slug >/dev/null
            declare -f disk_part >/dev/null
            declare -f nds_realize_run >/dev/null
        ' 2>&1
    ); then
        bts_pass "ok"
        console "  ✓ prepare_action_runtime: loads deps without pre-source"
    else
        bts_fail "fail"
        console "  ✗ prepare_action_runtime: loads deps without pre-source"
        console "    ${prepare_out}"
    fi
}
